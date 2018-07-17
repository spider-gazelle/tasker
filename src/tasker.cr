require "bisect"
require "./tasker/tasks"

class Tasker
  @@default : Tasker?

  @sync_period : Float64
  @timer : Concurrent::Future(Nil)?

  def initialize(sync_period = 2.minutes.total_milliseconds)
    @scheduled = [] of Tasker::Task
    @schedules = Set(Tasker::Task).new
    @sync_period = sync_period / 1000.0_f64

    # Next schedule time
    @next = Int64::MAX
  end

  def self.instance
    scheduler = @@default
    return scheduler if scheduler
    @@default = Tasker.new
  end

  def self.next_tick(&block) : Concurrent::Future(Nil)
    delay(0) { block.call; nil }
  end

  # Creates a once off task that occurs at a particular date and time
  def at(time : Time, &callback)
      task = Tasker::OneShot.new(self, time, &callback)
      task.schedule
      task
  end

  # Creates a once off task that occurs in the future
  def in(span : Time::Span, &callback)
      task = Tasker::OneShot.new(self, span.from_now, &callback)
      task.schedule
      task
  end

  # Creates repeating task
  # Schedules the repeat after executing the task
  def every(span : Time::Span, &callback)
      task = Tasker::Repeat.new(self, span, &callback)
      task.schedule
      task
  end

  def schedule(task : Task)
    return unless task.next_scheduled

    # Remove the task from the scheduled list and ensure it is in the schedules set
    if @schedules.includes?(task)
      @scheduled.delete(task)
    else
      @schedules << task
    end

    # optimal algorithm for inserting into an already sorted list
    @scheduled.insort(task)

    # Update the timer
    check_timer
  end

  def cancel(task : Tasker::Task)
    @scheduled.delete(task)
    @schedules.delete(task)
    check_timer
  end

  def num_schedules
    @scheduled.size
  end

  def cancel_all
    @scheduled.dup.each { |task| cancel(task) }
  end


  private def check_timer
    task = @scheduled[0]?
    update_timer if task && (task.next_epoch < @next)
  end

  private def update_timer
    time = @scheduled[0].not_nil!.next_epoch
    @next = time
    now = Time.now.epoch_ms
    period = time - now

    # Calculate the delay period
    seconds = if period < 0
      0
    else
      period.to_f64 / 1000.0_f64
    end

    # Cancel any existing timers
    timer = @timer
    timer.cancel if timer

    if seconds > @sync_period
      # We don't want to sleep for 3 days (for example) as the timer won't be accurate
      # Want to sync with the realtime clock every now and then
      @timer = delay(@sync_period) { update_timer; nil }
    else
      @timer = delay(seconds) { trigger; nil }
    end
  end

  private def trigger
    @next = Int64::MAX
    task = @scheduled.shift.not_nil!
    @schedules.delete(task)

    # This is the task callback
    task.trigger
  ensure
    check_timer
  end
end

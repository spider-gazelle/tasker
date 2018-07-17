require "cron_parser"

class Tasker; end

class Tasker::Task
  include Comparable(Tasker::Task)

  @callback : Proc(Nil)?

  def initialize(@scheduler)
    @created = Time.now
    @trigger_count = 0_i64
  end

  getter created : Time
  getter scheduler : Tasker
  getter trigger_count : Int64
  getter last_scheduled : Time?
  getter next_scheduled : Time?

  def next_epoch
    @next_scheduled.not_nil!.epoch_ms
  end

  # required for comparable
  def <=>(task)
      @next_scheduled.not_nil! <=> task.next_scheduled.not_nil!
  end

  def cancel
    @next_scheduled = nil
    @scheduler.cancel(self)
  end

  def callback(&block)
    @callback = block
  end

  def callback
    @callback.not_nil!
  end

  def schedule
    @scheduler.schedule(self)
    self
  end

  def trigger
    @trigger_count += 1
    callback.call
  end
end

class Tasker::OneShot < Tasker::Task
  def initialize(scheduler, at, &block)
    super(scheduler)
    @next_scheduled = at
    @callback = block
  end

  def trigger
    @last_scheduled = @next_scheduled
    @next_scheduled = nil
    super
  end
end

class Tasker::Repeat < Tasker::Task
  def initialize(scheduler, @period : Time::Span, &block)
    super(scheduler)
    @callback = block
  end

  def schedule
    @last_scheduled = @next_scheduled
    @next_scheduled = @period.from_now
    @scheduler.schedule(self)
    self
  end

  def pause
    cancel
  end

  def resume
    last = @last_scheduled
    schedule
    @last_scheduled = last
  end

  def trigger
    Tasker.next_tick { schedule }
    super
  end
end

class Tasker::CRON < Tasker::Task
  property location : Time::Location

  def initialize(scheduler, cron, @location : Time::Location, &block)
    super(scheduler)
    @callback = block
    @cron = CronParser.new(cron)
  end

  def schedule
    @last_scheduled = @next_scheduled
    @next_scheduled = @cron.next(Time.now(@location))
    @scheduler.schedule(self)
    self
  end

  def pause
    cancel
  end

  def resume
    last = @last_scheduled
    schedule
    @last_scheduled = last
  end

  def trigger
    Tasker.next_tick { schedule }
    super
  end
end

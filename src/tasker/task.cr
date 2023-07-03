require "./timer"

abstract class Tasker::Task
  include Comparable(Tasker::Task)

  def initialize
    @created = Time.utc
    @trigger_count = 0_i64
  end

  @timer : Timer?

  getter created : Time
  getter trigger_count : Int64
  getter last_scheduled : Time?
  getter next_scheduled : Time?

  def next_epoch
    @next_scheduled.as(Time).to_unix_ms
  end

  # required for comparable
  def <=>(other)
    @next_scheduled.as(Time) <=> other.next_scheduled.as(Time)
  end

  def ==(other)
    self.object_id == other.object_id
  end

  def cancel(msg = "Task canceled") : Nil
    @timer.try &.cancel
    @timer = nil
  end

  abstract def resume
  abstract def trigger
  abstract def get

  def each(&)
    yield get
  end

  SYNC_PERIOD = 2.minutes.total_milliseconds / 1000.0_f64

  def schedule
    Log.trace { "task scheduling timer, id: #{self.object_id}" }

    now = Time.utc.to_unix_ms
    time = next_epoch
    period = time - now

    # Calculate the delay period
    seconds = if period < 0
                Log.trace { "scheduled for the past, id: #{self.object_id}" }
                0.0
              else
                period.to_f64 / 1000.0_f64
              end

    @timer = timer = Timer.new(seconds) { trigger }
    timer.start_timer
    self
  end
end

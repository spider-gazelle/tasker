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
    @next_scheduled.not_nil!.to_unix_ms
  end

  # required for comparable
  def <=>(task)
    @next_scheduled.not_nil! <=> task.next_scheduled.not_nil!
  end

  def ==(task)
    self.object_id == task.object_id
  end

  def cancel(msg = "Task canceled") : Nil
    @timer.try &.cancel
    @timer = nil
  end

  def resume; end

  def trigger; end

  def get; end

  def each
    yield get
  end

  SYNC_PERIOD = 2.minutes.total_milliseconds / 1000.0_f64

  def schedule
    now = Time.utc.to_unix_ms
    time = next_epoch
    period = time - now

    # Calculate the delay period
    seconds = if period < 0
                0
              else
                period.to_f64 / 1000.0_f64
              end

    timer = if seconds > SYNC_PERIOD
              # We don't want to sleep for 3 days (for example) as the timer won't be accurate
              # Want to sync with the realtime clock every now and then
              @timer = Timer.new(SYNC_PERIOD) { schedule; nil }
            else
              @timer = Timer.new(seconds) { trigger; nil }
            end

    timer.start_timer
    self
  end
end

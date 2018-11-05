abstract class Tasker::Task
  include Comparable(Tasker::Task)

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
    @next_scheduled.not_nil!.to_unix_ms
  end

  # required for comparable
  def <=>(task)
    @next_scheduled.not_nil! <=> task.next_scheduled.not_nil!
  end

  def cancel(msg = "Task canceled"); end

  def resume; end

  def trigger; end

  def get; end

  def schedule
    @scheduler.schedule(self)
    self
  end
end

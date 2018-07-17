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
    @next_scheduled = nil
    super
  end
end

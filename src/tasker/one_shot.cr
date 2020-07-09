class Tasker::OneShot(R) < Tasker::Task
  include Enumerable(R)

  def initialize(at, &block : -> R)
    @next_scheduled = at
    @future = Tasker::Future(R).new(block)
    @created = Time.utc
    @trigger_count = 0_i64
  end

  getter next_scheduled : Time?

  def trigger
    return if @future.state >= Future::State::Running
    @last_scheduled = @next_scheduled
    @next_scheduled = nil
    @trigger_count += 1
    @timer.try &.cancel
    @timer = nil
    @future.trigger
  end

  def cancel(msg = "Task canceled")
    super(msg)
    return if @future.state >= Future::State::Completed
    @next_scheduled = nil
    @future.cancel(msg)
  end

  def get
    @future.get
  end

  def each
    yield @future.get
  end
end

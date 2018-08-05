
class Tasker::OneShot(R) < Tasker::Task
  include Enumerable(R)

  def initialize(scheduler, at, &block : -> R)
    super(scheduler)
    @next_scheduled = at
    @future = Tasker::Future(R).new(block)
  end

  getter next_scheduled : Time?

  def trigger
    return if @future.state >= Future::State::Running
    @last_scheduled = @next_scheduled
    @next_scheduled = nil
    @trigger_count += 1
    @future.trigger
  end

  def cancel(msg = "Task canceled")
    return if @future.state >= Future::State::Completed
    @next_scheduled = nil
    @scheduler.cancel(self)
    @future.cancel(msg)
  end

  def get
    @future.get
  end

  def each
    yield @future.get
  end
end

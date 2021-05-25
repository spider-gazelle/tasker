require "./task"

abstract class Tasker::RepeatingTask(R) < Tasker::Task
  include Enumerable(R)

  def initialize(&block : -> R)
    @callback = block
    @future = Tasker::Future(R).new(@callback)
    super
  end

  getter next_scheduled : Time?

  private def next_future
    @future = Tasker::Future(R).new(@callback)
  end

  def cancel(msg = "Task canceled")
    super(msg)
    return if @future.state == Future::State::Canceled
    @next_scheduled = nil
    @future.cancel(msg)
  end

  def resume
    return if @future.state != Future::State::Canceled
    last = @last_scheduled
    next_future
    schedule
    @last_scheduled = last
  end

  def trigger
    return if @future.state >= Future::State::Running
    @trigger_count += 1
    @future.trigger
  ensure
    if @future.state != Future::State::Canceled
      next_future
      schedule
    end
  end

  def get
    @future.get
  end

  def each
    while @future.state != Future::State::Canceled
      yield @future.get
    end
  rescue error : ::Future::CanceledError
  end
end

abstract class Tasker::RepeatingTask(R) < Tasker::Task
  include Enumerable(R)

  def initialize(@scheduler, &block : -> R)
    super(scheduler)
    @callback = block
    @future = Tasker::Future(R).new(@callback)
  end

  getter next_scheduled : Time?

  private def next_future
    @future = Tasker::Future(R).new(@callback)
  end

  def cancel(msg = "Task canceled")
    return if @future.state == Future::State::Canceled
    @next_scheduled = nil
    @scheduler.cancel(self)
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
    spawn(same_thread: true) do
      @future.wait_complete
      if @future.state != Future::State::Canceled
        next_future
        schedule
      end
    end
    @trigger_count += 1
    @future.trigger
  end

  def get
    @future.get
  end

  def each
    while @future.state != Future::State::Canceled
      yield @future.get
    end
  rescue error : Concurrent::CanceledError
  end
end

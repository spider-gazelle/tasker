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
    synchronize do
      super(msg)
      return if @future.state == Future::State::Canceled
      @next_scheduled = nil
      @future.cancel(msg)
    end
  end

  def resume
    synchronize do
      return if @future.state != Future::State::Canceled
      last = @last_scheduled
      next_future
      schedule
      @last_scheduled = last
    end
  end

  def trigger
    synchronize do
      return if @future.state >= Future::State::Running
      @trigger_count += 1
    end
    # callback runs outside the lock — a concurrent cancel isn't blocked
    @future.trigger
  ensure
    # Record completion and decide on a reschedule under the lock. Because
    # #complete and #cancel both run here (or in #cancel) under the same lock,
    # a cancel that lands during the callback wins: #complete won't overwrite
    # Canceled, so a cancelled task is never rescheduled.
    synchronize do
      @future.complete
      if @future.state != Future::State::Canceled
        next_future
        schedule
      end
    end
  end

  def get
    @future.get
  end

  def each(&)
    while @future.state != Future::State::Canceled
      yield @future.get
    end
  rescue error : ::Future::CanceledError
  end
end

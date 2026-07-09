require "./task"

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
    synchronize do
      return if @future.state >= Future::State::Running
      @last_scheduled = @next_scheduled
      @next_scheduled = nil
      @trigger_count += 1
    end
    # callback runs outside the lock so a concurrent cancel isn't blocked
    @future.trigger
    # record completion under the lock, serialised with #cancel; #complete
    # won't overwrite a cancel that landed while the callback was running.
    synchronize { @future.complete }
  end

  def cancel(msg = "Task canceled")
    synchronize do
      super(msg)
      return if @future.state >= Future::State::Completed
      @next_scheduled = nil
      @future.cancel(msg)
    end
  end

  def get
    @future.get
  end

  def resume
    raise "only repeating tasks can be resumed"
  end
end

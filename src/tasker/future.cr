require "future"

class Tasker::Future(R) < ::Future::Compute(R)
  def initialize(block : -> R)
    super(run_immediately: false, &block)

    # Calling #get should never execute the future
    @state = State::Delayed
  end

  # The future is holding the state for our scheduled task
  getter state

  # As we are controlling the delay we need direct access to run_compute
  def trigger
    run_compute
  end

  # We also want direct access to wait without grabbing the computed response
  def wait_complete
    wait
  end

  # Records the terminal state once the callback has finished. The task invokes
  # this under its own lock — the same lock `#cancel` holds — so completion and
  # cancellation are serialised without this class needing a mutex of its own.
  # Completion never overwrites a cancel, so `state == Canceled` reliably means
  # "the user cancelled; do not reschedule".
  def complete
    @state = State::Completed unless @state == State::Canceled
  end

  # We'll force the state into canceled as we use this to prevent rescheduling
  def cancel(msg)
    super(msg)
    @state = State::Canceled
  end

  # Runs the callback and closes the channel to release any `#get` waiters, but
  # deliberately leaves the terminal state to `#complete`. Setting the state
  # here would race a concurrent `#cancel`; deferring it to the task (which sets
  # it under the task lock) keeps the complete-vs-cancel decision race-free
  # without a lock inside the future.
  private def run_compute
    @value = @block.call
  rescue ex
    @error = ex
  ensure
    @channel.close
  end
end

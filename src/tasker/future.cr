class Tasker::Future(R) < Concurrent::Future(R)
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

  # We'll force the state into canceled as we use this to prevent rescheduling
  def cancel(msg)
    super(msg)
    @state = State::Canceled
  end
end

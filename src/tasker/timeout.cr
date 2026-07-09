class Tasker
  class Timeout < Exception
  end

  struct TimeoutHander(Output)
    def initialize(@period : Time::Span, &@callback : -> Output)
    end

    def execute!
      success = Channel(Output).new(1)
      failure = Channel(Exception).new(1)

      # Run the action on its own fiber. We deliberately avoid manually creating
      # and resuming a fiber here: manual `Fiber#resume` bypasses the scheduler
      # and is unsafe under Crystal's multi-threaded execution contexts. The
      # channels below already provide the required synchronisation.
      spawn(name: "tasker-timeout") { perform_action(success, failure) }

      # wait for the action to complete
      select
      when result = success.receive
        result
      when error = failure.receive
        raise error
        # NOTE:: the timeout won't fire if there is a result and the timeout is negative
        # basically this select statement works as expected
      when timeout(@period)
        raise Timeout.new("timeout after #{@period}")
      end
    end

    protected def perform_action(success, failure)
      result = @callback.call
      success.send result
    rescue error
      failure.send(error)
    end
  end
end

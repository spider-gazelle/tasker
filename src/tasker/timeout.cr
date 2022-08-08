class Tasker
  class Timeout < Exception
  end

  struct TimeoutHander(Output)
    def initialize(@period : Time::Span, @same_thread : Bool = true, &@callback : -> Output)
    end

    def execute!
      success = Channel(Output).new(1)
      failure = Channel(Exception).new(1)

      if @same_thread
        fiber = Fiber.new { perform_action(success, failure) }

        # scheudle this fiber to run again
        Fiber.current.enqueue
        start = Time.monotonic

        # start the action that we want to perform
        fiber.resume
        elapsed = Time.monotonic - start
      else
        spawn { perform_action(success, failure) }
        elapsed = 0.seconds
      end

      # wait for the action to complete
      select
      when result = success.receive
        result
      when error = failure.receive
        raise error
        # NOTE:: the timeout won't fire if there is a result and the timeout is negative
        # basically this select statement works as expected
      when timeout(@period - elapsed)
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

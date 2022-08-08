class Tasker
  class Timeout < Exception
  end

  struct TimeoutHander(Output)
    def initialize(@period : Time::Span, @same_thread : Bool = true, &@callback : -> Output)
    end

    def execute!
      success = Channel(Output).new
      failure = Channel(Exception).new

      spawn(same_thread: @same_thread) { perform_action(success, failure) }

      select
      when result = success.receive
        result
      when error = failure.receive
        raise error
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

# a class designed to allow sleeping fibers to be cancelled
class Timer
  def initialize(@sleep_for : Float64, &@callback : -> _)
    @cancelled = false
    @cancel = Channel(Bool).new
  end

  def start_timer : Nil
    Log.trace { "timer start called, id: #{self.object_id}" }
    spawn(same_thread: true) { schedule_wait }
    Fiber.yield
  end

  def cancel : Nil
    return if @cancelled
    Log.trace { "timer cancel requested, id: #{self.object_id}" }
    @cancelled = true
    begin
      @cancel.send(true)
    rescue
    end
  end

  private def schedule_wait
    Log.trace { "timer waiting for #{@sleep_for} seconds, id: #{self.object_id}" }

    select
    when @cancel.receive
      Log.trace { "timer cancelled, id: #{self.object_id}" }
    when timeout(@sleep_for.seconds)
      if !@cancelled
        Log.trace { "timer fired, id: #{self.object_id}" }
        @cancelled = true
        @callback.call
      else
        Log.trace { "timer fired but ignored as cancelled, id: #{self.object_id}" }
      end
    end
  rescue error
    Log.warn(exception: error) { "error in tasker scheduler" }
  ensure
    @cancelled = true
    @cancel.close
  end
end

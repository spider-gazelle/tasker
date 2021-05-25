# a class designed to allow sleeping fibers to be cancelled
class Timer
  def initialize(@sleep_for : Float64, &@callback : -> _)
    @cancelled = false
    @cancel = Channel(Bool).new
  end

  def start_timer : Nil
    Log.trace { "timer start called, id: #{self.object_id}" }
    spawn(same_thread: true) do
      Log.trace { "timer waiting for #{@sleep_for} seconds, id: #{self.object_id}" }
      select
      when @cancel.receive
        Log.trace { "timer cancelled, id: #{self.object_id}" }
      when timeout(@sleep_for.seconds)
        Log.trace { "timer fired, id: #{self.object_id}" }
        @cancelled = true
        @callback.call
      end
    end
    Fiber.yield
  end

  def cancel : Nil
    return if @cancelled
    Log.trace { "timer cancel requested, id: #{self.object_id}" }
    @cancelled = true
    @cancel.send(true)
  end
end

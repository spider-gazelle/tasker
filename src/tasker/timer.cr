# a class designed to allow sleeping fibers to be cancelled
class Timer
  def initialize(@sleep_for : Float64, &@callback : -> _)
    @cancelled = false
    @cancel = Channel(Bool).new
  end

  def start_timer : Nil
    spawn(same_thread: true) do
      select
      when @cancel.receive
      when timeout(@sleep_for.seconds)
        @cancelled = true
        @callback.call
      end
    end
    Fiber.yield
  end

  def cancel : Bool
    return true if @cancelled
    @cancelled = true
    @cancel.send(true)
    true
  end
end

# a class designed to allow sleeping fibers to be cancelled
class Timer
  def initialize(sleep_for, &block)
    @cancelled = false
    @fiber = Fiber.new do
      sleep sleep_for
      block.call unless @cancelled
    end
  end

  def start_timer : Nil
    Fiber.current.enqueue
    @fiber.resume
  end

  def cancel : Bool
    return true if @cancelled
    @cancelled = true
    if !@fiber.dead? && @fiber.resumable?
      Fiber.current.enqueue
      @fiber.resume
    end
    @cancelled
  end
end

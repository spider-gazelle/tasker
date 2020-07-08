# a class designed to allow sleeping fibers to be cancelled
class Timer
  def initialize(sleep_for, &block)
    @cancelled = false
    @fiber = Fiber.new do
      sleep sleep_for
      block.call unless @cancelled
    end
  end

  def start_timer
    Fiber.current.enqueue
    @fiber.resume
  end

  def cancel
    @cancelled = true
    if !@fiber.dead? && @fiber.resumable?
      Fiber.current.enqueue
      @fiber.resume
    end
  end
end

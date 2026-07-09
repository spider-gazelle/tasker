require "./repeating_task"

class Tasker::Repeat(R) < Tasker::RepeatingTask(R)
  def initialize(@period : Time::Span, &block : -> R)
    super(&block)
  end

  getter next_scheduled : Time?

  def schedule
    synchronize do
      return self if @future.state == Future::State::Canceled
      @last_scheduled = @next_scheduled
      @next_scheduled = @period.from_now
      super
    end
    self
  end
end

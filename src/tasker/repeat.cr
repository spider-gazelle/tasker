require "./repeating_task"

class Tasker::Repeat(R) < Tasker::RepeatingTask(R)
  def initialize(@period : Time::Span, &block : -> R)
    super(&block)
  end

  getter next_scheduled : Time?

  def schedule
    return if @future.state == Future::State::Canceled
    @last_scheduled = @next_scheduled
    @next_scheduled = @period.from_now
    super
    self
  end
end

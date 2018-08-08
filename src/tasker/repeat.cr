class Tasker::Repeat(R) < Tasker::RepeatingTask(R)
  def initialize(scheduler, @period : Time::Span, &block : -> R)
    super(scheduler, &block)
  end

  getter next_scheduled : Time?

  def schedule
    return if @future.state == Future::State::Canceled
    @last_scheduled = @next_scheduled
    @next_scheduled = @period.from_now
    @scheduler.schedule(self)
    self
  end
end

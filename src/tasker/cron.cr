require "cron_parser"

class Tasker::CRON(R) < Tasker::RepeatingTask(R)
  def initialize(scheduler, cron, @location : Time::Location, &block : -> R)
    super(scheduler, &block)
    @cron = CronParser.new(cron)
  end

  property location : Time::Location
  getter next_scheduled : Time?

  def schedule
    return if @future.state == Future::State::Canceled
    @last_scheduled = @next_scheduled
    @next_scheduled = @cron.next(Time.local(@location))
    @scheduler.schedule(self)
    self
  end
end

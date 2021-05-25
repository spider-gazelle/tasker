require "cron_parser"
require "./repeating_task"

class Tasker::CRON(R) < Tasker::RepeatingTask(R)
  def initialize(cron, @location : Time::Location, &block : -> R)
    @cron = CronParser.new(cron)
    super(&block)
  end

  property location : Time::Location
  getter next_scheduled : Time?

  def schedule
    return if @future.state == Future::State::Canceled
    @last_scheduled = @next_scheduled
    @next_scheduled = @cron.next(Time.local(@location))
    super
  end
end

require "log"

class Tasker
  Log = ::Log.for("tasker")

  module Methods
    # Creates a once off task that occurs at a particular date and time
    def at(time : Time, &callback : -> _) : Tasker::OneShot
      Tasker::OneShot.new(time, &callback).schedule.not_nil!
    end

    # Creates a once off task that occurs in the future
    def in(span : Time::Span, &callback : -> _) : Tasker::OneShot
      Tasker::OneShot.new(span.from_now, &callback).schedule.not_nil!
    end

    # Creates repeating task
    # Schedules the repeat after executing the task
    def every(span : Time::Span, &callback : -> _) : Tasker::Repeat
      Tasker::Repeat.new(span, &callback).schedule.not_nil!
    end

    # Create a repeating event that uses a CRON line to determine the trigger time
    def cron(line : String, timezone = Time::Location.local, &callback : -> _) : Tasker::CRON
      Tasker::CRON.new(line, timezone, &callback).schedule.not_nil!
    end
  end

  @@default : Tasker?

  def self.instance : Tasker
    scheduler = @@default
    return scheduler if scheduler
    @@default = Tasker.new
  end

  include Methods
  extend Methods
end

require "./tasker/*"

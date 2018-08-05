# Tasker

[![Build Status](https://travis-ci.org/spider-gazelle/tasker.svg?branch=master)](https://travis-ci.org/spider-gazelle/tasker)


A high precision scheduler for crystal lang.
Allows you to schedule tasks to run in the future and obtain the results.


Usage
=====

Grab an instance of the scheduler

```ruby
    require "tasker"

    # Grab the default scheduler - really only need a single instance per application
    schedule = Tasker.instance
```


At a time in the future

```ruby
    schedule.at(20.seconds.from_now) { perform_action }

    # If you would like the value of that result
    # returns value or raises error - a Concurrent::Future
    schedule.at(20.seconds.from_now) { perform_action }.get
```


After some period of time

```ruby
    schedule.in(20.seconds) { perform_action }
```


Repeating every time period

```ruby
    task = schedule.every(2.milliseconds) { perform_action }
    # Canceling stops the schedule from running
    task.cancel
    # Resume can be used to restart a canceled schedule
    task.resume
```

You can grab the values of repeating schedules too

```ruby
    tick = 0
    task = schedule.every(2.milliseconds) { tick += 1; tick }

    # Calling get will pause until after the next schedule has run
    task.get == 1 # => true
    task.get == 2 # => true
    task.get == 3 # => true

    # It also works as an enumerable
    # NOTE:: this will only stop counting once the schedule is canceled
    task.each do |count|
      puts "The count is #{count}"
      task.cancel if count > 5
    end
```


Running a CRON job

```ruby
    # Run a job at 7:30am every day
    schedule.cron("30 7 * * *") { perform_action }

    # For running in a job in a particular time zone:
    berlin = Time::Location.load("Europe/Berlin")
    schedule.cron("30 7 * * *", berlin) { perform_action }

    # Also supports pause, resume and enumeration
```

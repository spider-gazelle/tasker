# Tasker

[![Build Status](https://github.com/spider-gazelle/tasker/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/spider-gazelle/tasker/actions/workflows/CI.yml)

A high precision scheduler for crystal lang.
Allows you to schedule tasks to run in the future and obtain the results.

Usage
=====

At a time in the future

```crystal
    Tasker.at(20.seconds.from_now) { perform_action }

    # If you would like the value of that result
    # returns value or raises error - a Future
    Tasker.at(20.seconds.from_now) { perform_action }.get
```

After some period of time

```crystal
    Tasker.in(20.seconds) { perform_action }
```

Repeating every time period

```crystal
    task = Tasker.every(2.milliseconds) { perform_action }
    # Canceling stops the schedule from running
    task.cancel
    # Resume can be used to restart a canceled schedule
    task.resume
```

You can grab the values of repeating schedules too

```crystal
    tick = 0
    task = Tasker.every(2.milliseconds) { tick += 1; tick }

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

```crystal
    # Run a job at 7:30am every day
    Tasker.cron("30 7 * * *") { perform_action }

    # For running in a job in a particular time zone:
    berlin = Time::Location.load("Europe/Berlin")
    Tasker.cron("30 7 * * *", berlin) { perform_action }

    # Also supports pause, resume and enumeration
```

Timeout an operation
NOTE:: technically the operation isn't cancelled on timeout as there is no fiber cancel in crystal yet / no way to unwind stack consistently

```crystal
    # Run some code that is expected to complete within a certain time period
    result = Tasker.timeout(10.seconds) { perform_action }
```

## Pipelines

a non-blocking, asynchronous pipeline where each step only processes the input if it's not already processing the previous input.

```crystal
pipeline = Tasker::Pipeline(Input, Output).new("name") do |input|
  process(input) # => Output
end

pipeline.chain { |output_of_first_step|
  next_step(output_of_first_step)
}.subscribe { |output|
  # a subscribe step is always run, even if it's already running
  publish output
}
```

The idea is to maximise throughput with minimal latency.
Make sure to use the `-Dpreview_mt` flag when building.

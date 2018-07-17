# Tasker

A scheduler for crystal lang. Allows you to schedule tasks to run in the future.


Usage
=====

Delay execution of a task

```ruby
    Tasker.next_tick { perform_action }
```


Grab an instance of the scheduler

```ruby
    require "tasker"

    # Grab the default scheduler - really only need a single instance per application
    schedule = Tasker.instance
```


At a time in the future

```ruby
    schedule.at(20.seconds.from_now) { perform_action }
```


After some period of time

```ruby
    schedule.in(20.seconds) { perform_action }
```


Repeating every time period

```ruby
    task = schedule.every(20.seconds) { perform_action }
    sleep 40
    # Pausing stops the schedule from running
    task.pause
    sleep 40
    task.resume
```


Running a CRON job

```ruby
    # Run a job at 7:30am every day
    schedule.cron("30 7 * * *") { perform_action }

    # Also supports pause and resume
```

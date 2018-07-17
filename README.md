# Tasker

A scheduler for crystal lang. Allows you to schedule tasks to run in the future.


Usage
=====

```ruby
    require "tasker"

    # Grab the default scheduler - really only need a single instance per application
    schedule = Tasker.instance
    schedule.at(20.seconds.from_now) { perform_action }
```

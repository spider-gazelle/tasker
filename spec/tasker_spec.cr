require "spec"
require "../src/tasker"

describe Tasker do
  Spec.before_each do
    Tasker.instance.cancel_all
  end

  it "should work with sets" do
    sched = Tasker.instance
    ran = 0

    time = 2.milliseconds.from_now
    task1 = sched.at(time) { ran += 1 }
    task2 = sched.at(time) { ran += 1 }

    set = Set(Tasker::Task).new
    set << task1
    set << task2

    set.size.should eq(2)

    set.delete(task1)
    set.size.should eq(1)
  end

  it "should work with arrays" do
    sched = Tasker.instance
    ran = 0

    time = 2.milliseconds.from_now
    task1 = sched.at(time) { ran += 1 }
    task2 = sched.at(time) { ran += 1 }

    set = [task1, task2]

    set.size.should eq(2)

    set.delete(task1)
    set.size.should eq(1)
  end

  it "should schedule a task to run in the future" do
    sched = Tasker.instance
    ran = false
    sched.at(2.milliseconds.from_now) { ran = true }

    sleep 1.milliseconds
    sched.num_schedules.should eq(1)
    ran.should eq(false)

    sleep 2.milliseconds
    ran.should eq(true)
    sched.num_schedules.should eq(0)
  end

  it "should cancel a scheduled task" do
    sched = Tasker.instance
    ran = false
    task = sched.at(2.milliseconds.from_now) { ran = true }

    sleep 1.milliseconds
    task.cancel

    sleep 2.milliseconds
    ran.should eq(false)
    sched.num_schedules.should eq(0)
  end

  it "should cancel only the specified task" do
    sched = Tasker.instance
    ran = 0

    time = 2.milliseconds.from_now
    task1 = sched.at(time) { ran += 1 }
    sched.at(time) { ran += 1 }
    sched.num_schedules.should eq(2)

    sleep 1.milliseconds
    task1.cancel
    sched.num_schedules.should eq(1)

    sleep 2.milliseconds
    ran.should eq(1)
    sched.num_schedules.should eq(0)
  end

  it "should schedule a task to run after a period of time" do
    sched = Tasker.instance
    ran = false
    sched.in(2.milliseconds) { ran = true }

    sleep 1.milliseconds
    sched.num_schedules.should eq(1)
    ran.should eq(false)

    sleep 2.milliseconds
    ran.should eq(true)
    sched.num_schedules.should eq(0)
  end

  it "should be possible to obtain the return value of the task" do
    sched = Tasker.instance

    # Test execution
    task = sched.at(2.milliseconds.from_now) { true }
    task.get.should eq true

    # Test failure
    task = sched.at(2.milliseconds.from_now) { raise "was error" }
    begin
      task.get
      raise "not here"
    rescue error
      error.message.should eq "was error"
    end

    # Test cancelation
    task = sched.at(2.milliseconds.from_now) { true }
    spawn { task.cancel }
    begin
      task.get
      raise "failed"
    rescue error
      error.message.should eq "Task canceled"
    end
  end

  it "should schedule a repeating task" do
    sched = Tasker.instance
    ran = 0
    task = sched.every(2.milliseconds) { ran += 1 }

    sleep 1.milliseconds
    sched.num_schedules.should eq(1)
    ran.should eq(0)

    sleep 2.milliseconds
    ran.should eq(1)
    sched.num_schedules.should eq(1)

    sleep 2.milliseconds
    ran.should eq(2)
    sched.num_schedules.should eq(1)

    sleep 2.milliseconds
    ran.should eq(3)
    sched.num_schedules.should eq(1)

    task.cancel
  end

  it "should pause and resume a repeating task" do
    sched = Tasker.instance
    ran = 0
    task = sched.every(2.milliseconds) { ran += 1; ran }

    sleep 3.milliseconds
    ran.should eq(1)
    sched.num_schedules.should eq(1)

    sleep 2.milliseconds
    ran.should eq(2)
    sched.num_schedules.should eq(1)

    task.cancel
    sched.num_schedules.should eq(0)

    sleep 2.milliseconds
    ran.should eq(2)
    sched.num_schedules.should eq(0)

    task.resume
    sched.num_schedules.should eq(1)

    sleep 3.milliseconds
    ran.should eq(3)
    sched.num_schedules.should eq(1)

    task.cancel
  end

  it "should be possible to obtain the next value of a repeating" do
    sched = Tasker.instance
    ran = 0
    task = sched.every(2.milliseconds) do
      ran += 1
      raise "some error" if ran == 4
      ran
    end

    # Test execution
    task.get.should eq 1
    task.get.should eq 2
    task.get.should eq 3
    begin
      task.get.should eq 4
      raise "failed"
    rescue error
      error.message.should eq "some error"
    end
    task.get.should eq 5

    # Test cancelation
    spawn { task.cancel }
    begin
      task.get
      raise "failed"
    rescue error
      error.message.should eq "Task canceled"
    end
  end

  it "should act like an enumerable" do
    sched = Tasker.instance
    ran = 0
    task = sched.every(2.milliseconds) do
      ran += 1
      raise "other error" if ran == 4
      ran
    end

    results = [] of Int32
    begin
      task.each { |result| results << result }
      raise "failed with #{results}"
    rescue error
      error.message.should eq "other error"
    end
    results.should eq [1, 2, 3]
    task.cancel
  end

  it "should signal when there are no more tasks to process" do
    sched = Tasker.new
    ran = 0
    task = nil
    task = sched.every(1.milliseconds) do
      ran += 1
      task.not_nil!.cancel if ran > 3
    end
    channel = sched.no_more_tasks
    channel.receive
    ran.should eq(4)
  end

  # We calculate what the next minute is and then wait for it to roll by
  # If it takes too long then we fail it
  it "should schedule a CRON task" do
    sched = Tasker.instance
    time = Time.local
    minute = time.minute + 1
    minute = 0 if minute == 60
    ran = false
    task = sched.cron("#{minute} * * * *") { ran = true }

    seconds = (60 - time.second) // 2
    sleep seconds
    sched.num_schedules.should eq(1)
    ran.should eq(false)

    sleep seconds + 1
    ran.should eq(true)
    sched.num_schedules.should eq(1)

    task.cancel
  end
end

require "spec"
require "../src/tasker"

describe Tasker do
  Spec.before_each do
    Tasker.instance.cancel_all
  end

  it "should execute some code in the next tick" do
    ran = false
    Tasker.next_tick { ran = true }
    ran.should eq(false)
    sleep 1.milliseconds
    ran.should eq(true)
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

  it "should schedule a repeating task" do
    sched = Tasker.instance
    ran = 0
    sched.every(2.milliseconds) { ran += 1 }
    
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
  end

  it "should pause and resume a repeating task" do
    sched = Tasker.instance
    ran = 0
    task = sched.every(2.milliseconds) { ran += 1 }

    sleep 3.milliseconds
    ran.should eq(1)
    sched.num_schedules.should eq(1)

    sleep 2.milliseconds
    ran.should eq(2)
    sched.num_schedules.should eq(1)

    task.pause
    sched.num_schedules.should eq(0)

    sleep 2.milliseconds
    ran.should eq(2)
    sched.num_schedules.should eq(0)

    task.resume
    sched.num_schedules.should eq(1)

    sleep 3.milliseconds
    ran.should eq(3)
    sched.num_schedules.should eq(1)
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
    channel.empty?.should eq(true)
    channel.receive
    ran.should eq(4)
  end

  it "should schedule a CRON task" do
    sched = Tasker.instance
    time = Time.now
    minute = time.minute + 1
    minute = 0 if minute == 60
    ran = false
    task = sched.cron("#{minute} * * * *") { ran = true }

    seconds = (60 - time.second) / 2
    sleep seconds
    sched.num_schedules.should eq(1)
    ran.should eq(false)

    sleep seconds + 1
    ran.should eq(true)
    sched.num_schedules.should eq(1)
  end
end

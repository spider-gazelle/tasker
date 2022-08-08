require "spec"
require "../src/tasker"

if ENV["CI"]?
  ::Log.setup("*", :trace)

  Spec.before_suite do
    ::Log.builder.bind("*", backend: ::Log::IOBackend.new(STDOUT), level: ::Log::Severity::Trace)
  end
end

describe Tasker do
  tasks = [] of Tasker::Task
  ran = 0

  Spec.before_each do
    begin
      tasks.each &.cancel
      Fiber.yield
      tasks.clear
      GC.collect
    rescue error
      tasks = [] of Tasker::Task
      puts "\nfailed cancel running tasks\n#{error.inspect_with_backtrace}"
    end
    ran = 0
  end

  it "should work with sets" do
    sched = Tasker.instance

    time = 2.milliseconds.from_now
    task1 = sched.at(time) { nil }
    task2 = sched.at(time) { nil }

    set = Set(Tasker::Task).new
    set << task1
    set << task2

    tasks << task1
    tasks << task2

    set.size.should eq(2)

    set.delete(task1)
    set.size.should eq(1)
  end

  it "should work with arrays" do
    sched = Tasker.instance

    time = 2.milliseconds.from_now
    task1 = sched.at(time) { nil }
    task2 = sched.at(time) { nil }

    tasks << task1
    tasks << task2
    set = [task1, task2]

    set.size.should eq(2)

    set.delete(task1)
    set.size.should eq(1)
  end

  it "should schedule a task to run in the future" do
    sched = Tasker.instance
    ran = 0
    tasks << sched.at(40.milliseconds.from_now) { ran = 1 }

    sleep 20.milliseconds
    ran.should eq(0)

    sleep 30.milliseconds
    ran.should eq(1)
  end

  it "should cancel a scheduled task" do
    sched = Tasker.instance
    ran = 0
    task = sched.at(40.milliseconds.from_now) { ran = 1 }
    tasks << task

    sleep 20.milliseconds
    task.cancel

    # wait until the task should have run
    sleep 40.milliseconds
    ran.should eq(0)
  end

  it "should cancel only the specified task" do
    sched = Tasker.instance
    ran = 0

    time = 40.milliseconds.from_now
    task1 = sched.at(time) { ran += 1 }
    tasks << sched.at(time) { ran += 1 }
    tasks << task1

    sleep 20.milliseconds
    task1.cancel

    sleep 30.milliseconds
    ran.should eq(1)
  end

  it "should run both a single task and a repeating task" do
    sched = Tasker.instance
    ran = 0

    sched.in(20.milliseconds) { ran += 1 }
    task2 = sched.every(40.milliseconds) { ran += 1 }

    sleep 100.milliseconds
    task2.cancel
    ran.should eq(3)
  end

  it "should schedule a task to run after a period of time" do
    sched = Tasker.instance
    ran = 0
    tasks << sched.in(40.milliseconds) { ran = 1 }

    sleep 20.milliseconds
    ran.should eq(0)

    sleep 30.milliseconds
    ran.should eq(1)
  end

  it "should be possible to obtain the return value of the task" do
    sched = Tasker.instance

    # Test execution
    task = sched.at(2.milliseconds.from_now) { true }
    tasks << task
    task.get.should eq true

    # Test failure
    task = sched.at(2.milliseconds.from_now) { raise "was error" }
    tasks << task
    begin
      task.get
      raise "not here"
    rescue error
      error.message.should eq "was error"
    end

    # Test cancelation
    task = sched.at(2.milliseconds.from_now) { true }
    tasks << task
    spawn(same_thread: true) { task.cancel }
    begin
      task.get
      raise "failed"
    rescue error
      error.message.should eq "Task canceled"
    end
  end

  it "should schedule a repeating task" do
    sched = Tasker.instance
    repeat_count = 0
    task = sched.every(40.milliseconds) { repeat_count += 1 }

    begin
      tasks << task

      sleep 10.milliseconds
      repeat_count.should eq(0)

      sleep 50.milliseconds
      repeat_count.should eq(1)

      sleep 40.milliseconds
      repeat_count.should eq(2)

      sleep 40.milliseconds
      repeat_count.should eq(3)
    rescue error
      puts "\nfailed cancel running tasks\n#{error.inspect_with_backtrace}"
    ensure
      task.cancel
    end
  end

  it "should pause and resume a repeating task" do
    sched = Tasker.instance
    run_count = 0
    task = sched.every(80.milliseconds) { run_count += 1; run_count }

    begin
      tasks << task

      sleep 100.milliseconds
      run_count.should eq(1)

      sleep 80.milliseconds
      run_count.should eq(2)

      task.cancel

      sleep 80.milliseconds
      run_count.should eq(2)

      task.resume

      sleep 100.milliseconds
      run_count.should eq(3)
    rescue error
      puts "\nfailed cancel running tasks\n#{error.inspect_with_backtrace}"
    ensure
      task.cancel
    end
  end

  it "should be possible to obtain the next value of a repeating" do
    sched = Tasker.instance
    ran = 0
    task = sched.every(2.milliseconds) do
      ran += 1
      raise "some error" if ran == 4
      ran
    end

    begin
      tasks << task

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
      spawn(same_thread: true) { task.cancel }
      begin
        task.get
        raise "failed"
      rescue error
        error.message.should eq "Task canceled"
      end
    rescue error
      puts "\nfailed cancel running tasks\n#{error.inspect_with_backtrace}"
    ensure
      task.cancel
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

    begin
      tasks << task

      results = [] of Int32
      begin
        task.each { |result| results << result }
        raise "failed with #{results}"
      rescue error
        error.message.should eq "other error"
      end
      results.should eq [1, 2, 3]
    rescue error
      puts "\nfailed cancel running tasks\n#{error.inspect_with_backtrace}"
    ensure
      task.cancel
    end
  end

  # We calculate what the next minute is and then wait for it to roll by
  # If it takes too long then we fail it
  it "should schedule a CRON task" do
    sched = Tasker.instance
    time = Time.local
    minute = time.minute + 1
    minute = 0 if minute == 60
    ran = 0
    task = sched.cron("#{minute} * * * *") { ran = 1 }
    begin
      tasks << task

      seconds = (60 - time.second) // 2
      sleep seconds
      ran.should eq(0)

      sleep seconds + 1
      ran.should eq(1)
    rescue error
      puts "\nfailed cancel running tasks\n#{error.inspect_with_backtrace}"
    ensure
      task.cancel
    end
  end

  it "should timeout an operation" do
    expect_raises(Tasker::Timeout) do
      Tasker.timeout(100.milliseconds) { sleep 200.milliseconds }
    end
  end

  it "should return the result of a timeout operation" do
    result = Tasker.timeout(100.milliseconds) { 34 }
    result.should eq 34

    result = Tasker.timeout(-100.milliseconds) { "quick" }
    result.should eq "quick"
  end

  it "should propagate errors" do
    expect_raises(Channel::ClosedError) do
      Tasker.timeout(100.milliseconds) { raise Channel::ClosedError.new("testing"); 34 }
    end
  end
end

require "./spec_helper"

# A minimal Task whose fire time we can control directly, so the heap / index
# map can be exercised in isolation without relying on wall-clock firing.
private class FakeTask < Tasker::Task
  def initialize(at : Time?)
    super()
    @next_scheduled = at
  end

  def next_scheduled=(at : Time?)
    @next_scheduled = at
  end

  def resume
  end

  def trigger
    @trigger_count += 1
  end

  def get
    nil
  end
end

describe Tasker::Reactor do
  # ------------------------------------------------------------------
  # white-box: heap ordering + index-map integrity
  # tasks are scheduled an hour out so the reactor loop never fires them,
  # which makes the data-structure assertions fully deterministic.
  # ------------------------------------------------------------------
  describe "heap + index map" do
    it "keeps the earliest task at the head regardless of insert order" do
      reactor = Tasker::Reactor.new
      base = 1.hour.from_now
      tasks = (0...300).to_a.shuffle.map { |i| FakeTask.new(base + i.seconds) }
      tasks.each { |task| reactor.schedule(task) }

      reactor.pending.should eq 300
      reactor.consistent?.should be_true
      reactor.peek_task.as(Tasker::Task).next_scheduled.should eq base
    end

    it "stays consistent when cancelling head, middle and tail" do
      reactor = Tasker::Reactor.new
      base = 1.hour.from_now
      tasks = (0...7).map { |i| FakeTask.new(base + i.seconds) }
      tasks.each { |task| reactor.schedule(task) }

      reactor.peek_task.should eq tasks[0]
      reactor.consistent?.should be_true

      # middle
      reactor.cancel(tasks[3])
      reactor.pending.should eq 6
      reactor.consistent?.should be_true
      reactor.peek_task.should eq tasks[0]

      # head -> next earliest becomes the head
      reactor.cancel(tasks[0])
      reactor.pending.should eq 5
      reactor.consistent?.should be_true
      reactor.peek_task.should eq tasks[1]

      # tail (last inserted)
      reactor.cancel(tasks[6])
      reactor.pending.should eq 4
      reactor.consistent?.should be_true
    end

    it "empties cleanly when every task is cancelled in random order" do
      reactor = Tasker::Reactor.new
      tasks = (0...200).map { |i| FakeTask.new(1.hour.from_now + i.seconds) }
      tasks.each { |task| reactor.schedule(task) }

      tasks.shuffle.each do |task|
        reactor.cancel(task)
        reactor.consistent?.should be_true
      end

      reactor.pending.should eq 0
      reactor.peek_task.should be_nil
    end

    it "does not duplicate a task scheduled twice" do
      reactor = Tasker::Reactor.new
      task = FakeTask.new(1.hour.from_now)
      reactor.schedule(task)
      reactor.schedule(task)

      reactor.pending.should eq 1
      reactor.consistent?.should be_true
    end

    it "moves a task when re-scheduled to a new time" do
      reactor = Tasker::Reactor.new
      a = FakeTask.new(1.hour.from_now)
      b = FakeTask.new(2.hours.from_now)
      reactor.schedule(a)
      reactor.schedule(b)
      reactor.peek_task.should eq a

      # push a out past b and re-register (exercises the update branch)
      a.next_scheduled = 3.hours.from_now
      reactor.schedule(a)

      reactor.pending.should eq 2
      reactor.consistent?.should be_true
      reactor.peek_task.should eq b
    end

    it "ignores cancellation of a task that was never scheduled" do
      reactor = Tasker::Reactor.new
      scheduled = FakeTask.new(1.hour.from_now)
      reactor.schedule(scheduled)

      reactor.cancel(FakeTask.new(1.hour.from_now)) # never added
      reactor.pending.should eq 1
      reactor.consistent?.should be_true
    end

    it "remains consistent under interleaved random schedule/cancel" do
      reactor = Tasker::Reactor.new
      rng = Random.new(0x5eed)
      live = [] of FakeTask

      2000.times do
        if live.empty? || rng.rand < 0.6
          task = FakeTask.new(1.hour.from_now + rng.rand(100_000).seconds)
          reactor.schedule(task)
          live << task
        else
          reactor.cancel(live.delete_at(rng.rand(live.size)))
        end
        reactor.consistent?.should be_true
      end

      reactor.pending.should eq live.size
    end
  end

  # ------------------------------------------------------------------
  # behavioural: drive the real singleton reactor via the public API
  # ------------------------------------------------------------------
  describe "scheduling behaviour" do
    tasks = [] of Tasker::Task

    Spec.before_each do
      tasks.each(&.cancel)
      Fiber.yield
      tasks.clear
    end

    it "fires tasks in time order regardless of scheduling order" do
      fired = [] of Int32
      [50, 10, 40, 20, 30].each do |millis|
        tasks << Tasker.in(millis.milliseconds) { fired << millis }
      end

      sleep 120.milliseconds
      fired.should eq [10, 20, 30, 40, 50]
    end

    it "fires only the tasks that were not cancelled" do
      fired = [] of Int32
      by_ms = {} of Int32 => Tasker::Task
      [10, 20, 30, 40].each { |millis| by_ms[millis] = Tasker.in(millis.milliseconds) { fired << millis } }
      tasks.concat by_ms.values

      by_ms[20].cancel
      by_ms[40].cancel

      sleep 90.milliseconds
      fired.should eq [10, 30]
    end

    it "fires every task scheduled for the same instant" do
      count = 0
      at = 30.milliseconds.from_now
      10.times { tasks << Tasker.at(at) { count += 1 } }

      sleep 90.milliseconds
      count.should eq 10
    end

    it "wakes promptly for a task scheduled earlier than the current head" do
      fired = [] of Symbol
      tasks << Tasker.in(500.milliseconds) { fired << :late }
      sleep 10.milliseconds
      tasks << Tasker.in(20.milliseconds) { fired << :early }

      sleep 80.milliseconds
      fired.should eq [:early]
    end

    it "parks when empty and resumes when a new task arrives" do
      fired = [] of Symbol
      tasks << Tasker.in(10.milliseconds) { fired << :first }
      sleep 50.milliseconds # heap drains, reactor parks
      fired.should eq [:first]

      tasks << Tasker.in(10.milliseconds) { fired << :second }
      sleep 50.milliseconds
      fired.should eq [:first, :second]
    end

    it "does not let a blocking callback delay sibling tasks" do
      order = [] of Symbol
      tasks << Tasker.in(10.milliseconds) { sleep 120.milliseconds; order << :slow }
      tasks << Tasker.in(30.milliseconds) { order << :fast }

      sleep 70.milliseconds
      order.should eq [:fast] # fast ran while slow's callback is still sleeping

      sleep 100.milliseconds
      order.should eq [:fast, :slow]
    end
  end
end

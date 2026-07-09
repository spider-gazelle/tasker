require "./reactor"

abstract class Tasker::Task
  include Comparable(Tasker::Task)

  # Guards this task's mutable state (`@future`, `@next_scheduled`,
  # `@last_scheduled`, `@trigger_count`). The reactor now triggers callbacks on
  # arbitrary fibers/threads, so a user-thread `cancel` (or `resume`) can race
  # the reactor's `trigger`. Serialising those transitions keeps the future
  # reference and the "should I reschedule?" decision consistent, so a cancel
  # can never be silently undone by an in-flight reschedule.
  #
  # Reentrant because `trigger` and `resume` call `schedule`, which also locks,
  # and `cancel` locks before delegating to `super`. Lock ordering is always
  # task-lock first, then the reactor's mutex (reached via `schedule`/`cancel`);
  # the reactor never calls back into a locked task method, so no cycle exists.
  @state_lock = Mutex.new(:reentrant)

  def initialize
    @created = Time.utc
    @trigger_count = 0_i64
  end

  protected def synchronize(&)
    @state_lock.synchronize { yield }
  end

  getter created : Time
  getter trigger_count : Int64
  getter last_scheduled : Time?
  getter next_scheduled : Time?

  def next_epoch
    @next_scheduled.as(Time).to_unix_ms
  end

  # required for comparable
  def <=>(other)
    @next_scheduled.as(Time) <=> other.next_scheduled.as(Time)
  end

  def ==(other)
    self.object_id == other.object_id
  end

  def cancel(msg = "Task canceled") : Nil
    Tasker::Reactor.instance.cancel(self)
  end

  abstract def resume
  abstract def trigger
  abstract def get

  def each(&)
    yield get
  end

  SYNC_PERIOD = 2.minutes.total_milliseconds / 1000.0_f64

  def schedule
    Log.trace { "task registering with reactor, id: #{self.object_id}" }
    Tasker::Reactor.instance.schedule(self)
    self
  end
end

require "log"

# A single, process-wide timing reactor.
#
# Historically every pending `Tasker::Task` owned its own fiber that simply
# slept until the task was due. In a process running many schedules (and one
# short-lived timeout timer per in-flight queued command) that is thousands of
# sleeping fibers, each holding a fiber stack. Crystal's fiber stack pool grows
# to the high-water mark of live fibers and never fully returns it, so a large
# population of sleeping timer fibers permanently inflates RSS.
#
# The reactor replaces those per-task fibers with a single scheduler fiber that
# owns an indexed binary min-heap keyed on each task's next fire time. Pending
# tasks cost a heap entry, not a fiber. When a task is due the reactor spawns a
# short-lived fiber to run its callback — isolation is preserved (a blocking
# callback cannot stall the scheduler or sibling tasks), but a fiber only exists
# while a callback is actually executing.
class Tasker::Reactor
  Log = ::Log.for("tasker.reactor")

  @@instance : Tasker::Reactor?

  def self.instance : Tasker::Reactor
    @@instance ||= new
  end

  def initialize
    @mutex = Mutex.new(:reentrant)
    # binary min-heap of {fire_at, task}
    @heap = [] of Tuple(Time, Tasker::Task)
    # task => current heap index, for O(log n) cancellation
    @index = {} of Tasker::Task => Int32
    # buffered(1) so a scheduler can signal "wake & recompute" without blocking;
    # extra signals collapse harmlessly because the loop re-reads the heap head.
    @wake = Channel(Nil).new(1)
    @started = false
  end

  # Register (or re-register) *task* to fire at its `next_scheduled` time.
  def schedule(task : Tasker::Task) : Nil
    at = task.next_scheduled
    return if at.nil?

    @mutex.synchronize do
      if existing = @index[task]?
        # already queued — move it to the new time
        update(existing, at)
      else
        push({at, task})
      end
      start unless @started
    end

    # wake the loop so it re-evaluates the (possibly earlier) head
    @wake.send(nil) rescue nil
  end

  # Remove *task* so it will not fire.
  def cancel(task : Tasker::Task) : Nil
    @mutex.synchronize do
      if idx = @index[task]?
        delete_at(idx)
      end
    end
  end

  # :nodoc:
  # Number of tasks currently pending in the heap.
  def pending : Int32
    @mutex.synchronize { @heap.size }
  end

  # :nodoc:
  # The task at the head of the heap (earliest fire time), if any.
  def peek_task : Tasker::Task?
    @mutex.synchronize { @heap[0]?.try &.[](1) }
  end

  # :nodoc:
  # Diagnostic: returns true when the heap satisfies the min-heap invariant and
  # the task=>index map is fully consistent with the heap array (every task maps
  # to its actual position, sizes match, no stale or duplicate entries).
  def consistent? : Bool
    @mutex.synchronize do
      return false unless @index.size == @heap.size

      @heap.each_with_index do |entry, i|
        # index map points at the right slot
        return false unless @index[entry[1]]? == i

        # min-heap property against both children
        left = 2 * i + 1
        right = 2 * i + 2
        return false if left < @heap.size && @heap[left][0] < entry[0]
        return false if right < @heap.size && @heap[right][0] < entry[0]
      end

      true
    end
  end

  private def start : Nil
    @started = true
    spawn(same_thread: true) { run }
  end

  private def run : Nil
    loop do
      head = @mutex.synchronize { @heap[0]? }

      if head.nil?
        # nothing scheduled — park until something arrives
        @wake.receive
        next
      end

      delay = head[0] - Time.utc
      if delay <= Time::Span.zero
        fire_due
      else
        select
        when @wake.receive
          # a new (possibly earlier) task arrived — recompute
        when timeout(delay)
          fire_due
        end
      end
    end
  rescue error
    Log.error(exception: error) { "tasker reactor loop crashed; restarting" }
    spawn(same_thread: true) { run }
  end

  # Pop and fire every task whose deadline has passed. Each callback runs on its
  # own fiber so a slow/blocking callback can't hold up the reactor.
  private def fire_due : Nil
    now = Time.utc
    loop do
      task = @mutex.synchronize do
        head = @heap[0]?
        (head && head[0] <= now) ? pop[1] : nil
      end
      break unless task

      # bind to a non-nil local so the spawned closure doesn't capture a nilable
      due = task
      spawn(same_thread: true) { due.trigger }
    end
  end

  # ------------------------------------------------------------------
  # indexed binary min-heap (guarded by @mutex)
  # ------------------------------------------------------------------

  private def push(entry : Tuple(Time, Tasker::Task)) : Nil
    @heap << entry
    @index[entry[1]] = @heap.size - 1
    sift_up(@heap.size - 1)
  end

  private def pop : Tuple(Time, Tasker::Task)
    last = @heap.size - 1
    swap(0, last)
    entry = @heap.pop
    @index.delete(entry[1])
    sift_down(0) unless @heap.empty?
    entry
  end

  private def delete_at(idx : Int32) : Nil
    last = @heap.size - 1
    entry = @heap[idx]
    @index.delete(entry[1])
    if idx == last
      @heap.pop
      return
    end
    @heap[idx] = @heap.pop
    @index[@heap[idx][1]] = idx
    # restore heap order from idx (could need to move either direction)
    sift_down(idx)
    sift_up(idx)
  end

  private def update(idx : Int32, at : Time) : Nil
    task = @heap[idx][1]
    @heap[idx] = {at, task}
    sift_down(idx)
    sift_up(idx)
  end

  private def sift_up(i : Int32) : Nil
    while i > 0
      parent = (i - 1) // 2
      break if @heap[parent][0] <= @heap[i][0]
      swap(i, parent)
      i = parent
    end
  end

  private def sift_down(i : Int32) : Nil
    size = @heap.size
    loop do
      left = 2 * i + 1
      right = 2 * i + 2
      smallest = i
      smallest = left if left < size && @heap[left][0] < @heap[smallest][0]
      smallest = right if right < size && @heap[right][0] < @heap[smallest][0]
      break if smallest == i
      swap(i, smallest)
      i = smallest
    end
  end

  private def swap(a : Int32, b : Int32) : Nil
    @heap[a], @heap[b] = @heap[b], @heap[a]
    @index[@heap[a][1]] = a
    @index[@heap[b][1]] = b
  end
end

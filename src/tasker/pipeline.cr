class Tasker
  module Processor(Input)
    abstract def process(input : Input) : Bool
  end

  class Subscription(Input)
    include Processor(Input)

    def initialize(&@work : Input -> Nil)
    end

    def process(input : Input) : Bool
      @work.call input
      true
    end
  end

  # a lossy pipeline for realtime processing so any outputs are
  # as up to date as possible. This means some results might be
  # ignored at various stages in the pipeline.
  class Pipeline(Input, Output)
    include Processor(Input)

    def initialize(@name : String? = nil, &@work : Input -> Output)
      spawn { process_loop }
    end

    @work : Proc(Input, Output)
    @in : Channel(Input) = Channel(Input).new
    @chained : Array(Processor(Output)) = [] of Processor(Output)

    # the time it took to perform the last bit of work
    getter time : Time::Span = 0.seconds

    # is work being performed currently
    getter? idle : Bool = true

    # name of the pipeline
    getter name : String?

    # non-blocking send
    def process(input : Input) : Bool
      select
      when @in.send(input) then true
      else
        false
      end
    end

    # push the output of this pipeline task into the input
    # of the next task, if that task is idle
    def chain(name : String? = @name, &work : Output -> _)
      type_var = uninitialized Output
      proc = Pipeline(Output, typeof(work.call(type_var))).new(name, &work)
      @chained << proc
      proc
    end

    # :ditto:
    def chain(task : Pipeline(Output))
      @chained << task
      task
    end

    # push all the outputs of this task to the subscriber
    def subscribe(&work : Output -> Nil)
      proc = Subscription(Output).new(&work)
      @chained << proc
      proc
    end

    # :ditto:
    def subscribe(subscription : Subscription(Output))
      @chained << subscription
      subscription
    end

    # :nodoc:
    def finalize
      stop
    end

    # shutdown processing
    def close
      @in.close
    end

    # check if the pipline is running
    def closed?
      @in.closed?
    end

    protected def process_loop
      loop do
        return if @in.closed?
        begin
          @idle = true
          input = @in.receive
          t1 = Time.monotonic
          @idle = false
          output = @work.call input
          t2 = Time.monotonic
          @time = t2 - t1
          @chained.each(&.process(output))
        rescue Channel::ClosedError
        rescue error
          Log.error(exception: error) { "error in pipeline #{@name}" }
        end
      end
    end
  end
end

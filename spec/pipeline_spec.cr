require "./helper"

describe Tasker do
  it "should perform tasks in a pipeline" do
    add_invoke = 0
    multi_invoke = 0
    sub_invoke = 0
    result = 0.0

    pipeline = Tasker::Pipeline(Int32, Int32).new("name") { |input|
      sleep 0.1
      input
    }

    pipeline.chain { |input|
      sleep 0.2
      add_invoke += 1
      (input + 1).to_f
    }.chain { |input|
      sleep 0.3
      multi_invoke += 1
      input * 3
    }.subscribe { |output|
      sub_invoke += 1
      result = output
    }

    50.times do
      sleep 0.05
      pipeline.process 100
    end

    sleep 1

    sub_invoke.should eq multi_invoke
    (multi_invoke < add_invoke).should be_true

    result.should eq 303.0
  end
end

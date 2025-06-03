require "./spec_helper"

describe Tasker do
  it "should perform tasks in a pipeline" do
    add_invoke = 0
    multi_invoke = 0
    sub_invoke = 0
    result = 0.0

    pipeline = Tasker::Pipeline(Int32, Int32).new("name") { |input|
      sleep 100.milliseconds
      input
    }

    pipeline.chain { |input|
      sleep 200.milliseconds
      add_invoke += 1
      (input + 1).to_f
    }.chain { |input|
      sleep 300.milliseconds
      multi_invoke += 1
      input * 3
    }.subscribe { |output|
      sub_invoke += 1
      result = output
    }

    50.times do
      sleep 50.milliseconds
      pipeline.process 100
    end

    sleep 1.second

    sub_invoke.should eq multi_invoke
    (multi_invoke < add_invoke).should be_true

    result.should eq 303.0
  end
end

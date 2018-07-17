require "spec"
require "../src/tasker"

describe Tasker do
  it "should schedule a task to run in the future" do
    sched = Tasker.instance
    ran = false
    sched.at(0.3.seconds.from_now) { ran = true }
    sleep 0.2
    ran.should eq(false)
    sleep 0.2
    ran.should eq(true)
  end
end

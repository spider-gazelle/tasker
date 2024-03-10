require "spec"
require "../src/tasker"

if ENV["CI"]?
  ::Log.setup("*", :trace)

  Spec.before_suite do
    ::Log.builder.bind("*", backend: ::Log::IOBackend.new(STDOUT), level: ::Log::Severity::Trace)
  end
end

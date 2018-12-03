# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "bundler/setup"
require "memory_profiler"

report = MemoryProfiler.report do
  require "executable_mock"
end

puts "Ruby version: #{RUBY_VERSION}"
%i[total_retained total_allocated total_retained_memsize total_allocated_memsize].each do |key|
  puts "#{key}: #{report.send(key)}"
end

# Ruby version: 2.6.0
# total_retained: 1261
# total_allocated: 9235
# total_retained_memsize: 163370
# total_allocated_memsize: 1042233

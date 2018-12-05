# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))

require "bundler/setup"
require "memory_profiler"

require "executable_mock/stdlib"

report = MemoryProfiler.report do
  require "executable_mock"
end

puts "Ruby version: #{RUBY_VERSION}"
%i[total_allocated total_allocated_memsize total_retained total_retained_memsize].each do |key|
  puts "#{key}: #{report.send(key)}"
end

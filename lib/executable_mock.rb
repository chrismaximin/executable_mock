# frozen_string_literal: true

require "fileutils"
require "tempfile"
require "tmpdir"
require "yaml"
require "erb"
require "executable_mock/registry"

# TODO: When gemifying this, set min ruby version to 2.6
# TODO: Use Marshal instead of YAML for perf: https://interviewbubble.com/yaml-vs-json-performance-benchmark/

class ExecutableMock
  include Registry
  TEMPLATE_PATH = File.expand_path("executable_mock/template.rb.erb", __dir__)
  TEMPLATE = ERB.new(File.read(TEMPLATE_PATH))
  Error = Class.new(StandardError)

  attr_reader :file_path, :path_setup

  class << self
    def generate(name, mappings:, ruby_bin: RbConfig.ruby, directory: Dir.mktmpdir)
      instance = new(name, mappings: mappings, ruby_bin: ruby_bin, directory: directory)

      yield(instance).tap do |result|
        instance.finalize(result)
      end
    end

    def finalize_all
      registry.each(&:finalize)
    end
  end

  def initialize(name, mappings:, ruby_bin: RbConfig.ruby, directory: Dir.mktmpdir)
    @mappings = mappings
    @ruby_bin = ruby_bin
    @name = name
    @file_path = File.join(directory, name)
    @path_setup = %(PATH="#{directory}:$PATH")
    @call_error_log_file_path = Tempfile.new.path

    write_executable
    register_self
  end

  def finalize(command_result = nil)
    argvs_map = YAML.safe_load(File.read(counter_cache_path))
    check_call_error_log_file
    check_uncalled_argvs(argvs_map)
    check_mismatched_argvs_calls(argvs_map)
  rescue Error
    puts command_result if command_result
    raise
  ensure
    FileUtils.rm(@file_path)
    FileUtils.rm(counter_cache_path)
    FileUtils.rm(@call_error_log_file_path)
    deregister_self
  end

  def check_call_error_log_file
    return unless File.size?(@call_error_log_file_path)

    raise(Error, File.read(@call_error_log_file_path))
  end

  def check_uncalled_argvs(argvs_map)
    uncalled_argvs = argvs_map.select { |_, v| v.zero? }

    raise(Error, <<~MESSAGE) if uncalled_argvs.any?
      The following argvs were not called:
      #{uncalled_argvs.keys.join("\n")}
    MESSAGE
  end

  def check_mismatched_argvs_calls(argvs_map)
    mismatched_argvs_calls = @mappings.select do |argv, outputs|
      outputs.is_a?(Array) && outputs.size != argvs_map[argv]
    end

    raise(Error, <<~MESSAGE) if mismatched_argvs_calls.any?
      The following argvs were not called the correct number of times:
      #{mismatched_argvs_calls.inspect}
    MESSAGE
  end

  def counter_cache_path
    @counter_cache_path ||= begin
      Tempfile.new.path.tap do |file_path|
        yaml_string = @mappings.transform_values { 0 }.to_yaml
        File.open(file_path, "w") do |file|
          file.write(yaml_string)
        end
      end
    end
  end

  def write_executable
    bindings = {
      ruby_bin: @ruby_bin,
      mappings: @mappings,
      name: @name,
      call_error_log_file_path: @call_error_log_file_path,
      counter_cache_path: counter_cache_path
    }

    executable_contents = TEMPLATE.result_with_hash(bindings)

    File.open(@file_path, "w") do |file|
      file.write(executable_contents)
    end
    File.chmod(0o755, @file_path)
  end
end

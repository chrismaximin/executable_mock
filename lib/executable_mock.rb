# frozen_string_literal: true

require "executable_mock/stdlib"
require "executable_mock/registry"

class ExecutableMock
  include Registry
  TEMPLATE_PATH = File.expand_path("executable_mock/template.rb.erb", __dir__)
  TEMPLATE = ERB.new(File.read(TEMPLATE_PATH))
  Error = Class.new(StandardError)

  attr_reader :file_path, :path_setup

  class << self
    def generate(name, mappings, ruby_bin: RbConfig.ruby, directory: Dir.mktmpdir)
      instance = new(name, mappings, ruby_bin: ruby_bin, directory: directory)

      yield(instance).tap do |result|
        instance.finalize(result)
      end
    end

    def finalize_all
      registry.each(&:finalize)
    end
  end

  def initialize(name, mappings, ruby_bin: RbConfig.ruby, directory: Dir.mktmpdir)
    @mappings = mappings
    @ruby_bin = ruby_bin
    @name = name
    @file_path = File.join(directory, name)
    @path_setup = %(PATH="#{directory}:$PATH")
    call_error_log_file = Tempfile.new
    call_error_log_file.close
    @call_error_log_file_path = call_error_log_file.path

    write_executable
    register_self
  end

  def finalize(command_result = nil)
    called_argvs_map = Marshal.load(File.read(counter_cache_path)) # rubocop:disable Security/MarshalLoad
    check_call_error_log_file
    check_uncalled_argvs(called_argvs_map)
    check_mismatched_argvs_calls(called_argvs_map)
  rescue Error
    puts command_result if command_result
    raise
  ensure
    FileUtils.rm_f([@file_path, @call_error_log_file_path, counter_cache_path])
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
      data = Marshal.dump(@mappings.transform_values { 0 })
      Tempfile.new.tap do |file|
        file.write(data)
        file.close
      end.path
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

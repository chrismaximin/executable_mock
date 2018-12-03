# frozen_string_literal: true

require "open3"

RSpec.describe ExecutableMock do
  it "sets up the correct executable" do
    docker_mappings = {
      "run -d ruby:0.0" => "container-id-0",
      "container exec container-id-0 sh -c /the_command" => "command result"
    }

    result = ExecutableMock.generate("docker", docker_mappings) do |mock|
      run_executable(mock.path_setup)
    end

    expect(result).to eql("command result")
  end

  it "handles uncalled arguments" do
    docker_mappings = {
      "run -d ruby:0.0" => "container-id-0",
      "container exec container-id-0 sh -c /the_command" => "command result",
      "unused argument" => ""
    }

    begin
      no_output do
        ExecutableMock.generate("docker", docker_mappings) do |mock|
          run_executable(mock.path_setup)
        end
      end
    rescue ExecutableMock::Error => e
      expect(e.message).to eql("The following argvs were not called:\nunused argument\n")
    end
  end

  it "does not handle unsupported arguments" do
    docker_mappings = { "foo" => "bar" }

    begin
      no_output do
        ExecutableMock.generate("docker", docker_mappings) do |mock|
          run_executable(mock.path_setup)
        end
      end
    rescue ExecutableMock::Error => e
      expect(e.message).to eql("The executable `docker` does not support these args:\nrun -d ruby:0.0\n\nSupported:\nfoo")
    end
  end

  context ".finalize_all" do
    it "removes the executables" do
      docker_mock = ExecutableMock.new("docker", {})
      gcc_mock = ExecutableMock.new("gcc", {})

      expect(File.exist?(docker_mock.file_path)).to be true
      expect(File.exist?(gcc_mock.file_path)).to be true

      ExecutableMock.finalize_all

      expect(File.exist?(docker_mock.file_path)).to be false
      expect(File.exist?(gcc_mock.file_path)).to be false
    end
  end
end

def run_executable(path_setup)
  executable_path = Tempfile.new.path
  File.open(executable_path, "w") do |file|
    file.write(<<~SHELL)
      #!/bin/bash
      set -e
      cid=$(docker run -d ruby:0.0)
      echo -n $(docker container exec $cid sh -c /the_command)
    SHELL
  end
  File.chmod(0o755, executable_path)

  `#{path_setup} #{executable_path}`
ensure
  FileUtils.rm(executable_path)
end

def no_output
  RSpec::Mocks.with_temporary_scope do
    allow(STDOUT).to receive(:puts)
    yield
  end
end

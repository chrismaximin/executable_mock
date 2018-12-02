# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "executable_mock/version"

Gem::Specification.new do |spec|
  spec.name = "executable_mock"
  spec.version = ExecutableMock::VERSION
  spec.authors = ["Christophe Maximin"]
  spec.email = ["christophe.maximin@gmail.com"]

  spec.summary = "PLACEHOLDER"
  spec.description = "PLACEHOLDER"
  spec.homepage = "https://github.com/christophemaximin/executable_mock"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "https://github.com/christophemaximin/executable_mock/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").select { |f| f.match(%r{^(lib)/}) }
  end

  spec.require_paths = ["lib"]
  spec.required_ruby_version = ">= 2.6"
end

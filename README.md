# ExecutableMock

[![Gem Version](https://badge.fury.io/rb/executable_mock.svg)](https://badge.fury.io/rb/executable_mock)
[![Build Status](https://travis-ci.org/christophemaximin/executable_mock.svg?branch=master)](https://travis-ci.org/christophemaximin/executable_mock)
[![Maintainability](https://api.codeclimate.com/v1/badges/95d351d4ba7400934b1b/maintainability)](https://codeclimate.com/github/christophemaximin/executable_mock/maintainability)

**ExecutableMock** helps you quickly and easily generate mock executables, with a predefined list of inputs -> outputs.  
It is fast, lightweight, threadsafe, and has **zero external dependencies**. See the [Performance](#performance) section for more details.  

You can typically use it to test an executable which is in turn calling another executable whose behaviour you want to mock.

## Installation

```sh
$ gem install executable_mock
```

If you'd rather install it using `bundler`, in your `Gemfile`:  

```rb
gem "executable_mock"
```

## Basic Usage

Let's say you have a script called `your_script.sh`, which you want to test:

```sh
#!/bin/bash
version=$(docker run ruby:latest ruby -e 'puts RUBY_VERSION')
echo "The latest released version of Ruby is ${version}"
```

However you don't actually want to run the real `docker` executable every time this script runs in your tests.

Example of a test (RSpec style here, but it is compatible with anything as it is just pure Ruby):

```ruby
mappings = {
  "run ruby:latest ruby -e 'puts RUBY_VERSION'" => "1.2.3"
}

result = ExecutableMock.generate("docker", mappings) do |mock|
  # The docker executable that is generated is in a temporary folder.
  # For your script to be able to access it, we need to modify the PATH.
  # `mock.path_setup` will be equal to `PATH="/tmp/some/temporary/folder:$PATH"`
  `#{mock.path_setup} your_script.sh`
end

expect(result).to eql("The latest released version of Ruby is 1.2.3")
```

### Notes:

- `ExecutableMock` will raise an error if an argument present in the mappings is NOT called
- `ExecutableMock` will raise an error if an argument NOT present in the mappings is called
- You can make the same argument output a series a different strings by passing an array (`mappings = {"run -d ruby:latest" => ["container_id_1", "container_id_2"]}`)
- You can generate several executables without nesting blocks. Just call `ExecutableMock.new` with the same arguments, then `#finalize` on each mock object created, or `ExecutableMock.finalize_all` which will apply to all mock objects created within the Thread.

## Performance

### Operations per second (CPU)

Data gathered for Ruby 2.5.3 on a MacBook Pro with Intel(R) Core(TM) i7-4578U CPU @ 3.00GHz.  


| Script | Iterations | Realtime | OPS |
| :--- | :--- | ---: | ---: |
| [generate.ops.rb](performance/generate.ops.rb) | 1000 | 1.65s | 605 |
| [generate\_and\_execute.ops.rb](performance/generate_and_execute.ops.rb) | 100 | 8.88s | 11 |  


### Memory usage

ExecutableMock requires some Ruby Standard libraries (e.g. fileutils, set).
It wouldn't be realistic or fair to only measure memory allocations from "nothing", because most environments this gem is used in (e.g. Rails, RSpec) already require those standard libraries, so we're measuring here "Naked Ruby" and "Realistic Ruby" (with those libs already required).


| Ruby version| Require script | Total allocated | Total retained |
| :--- | :--- | ---: | ---: |
| 2.5.3 | [require (naked)](performance/require.memory.rb) | 558,074 bytes (6,589 objects) | 106,856 bytes (716 objects) |
| 2.5.3 | **[require (realistic)](performance/require_without_stdlib.memory.rb)** | 52,315 bytes (446 objects) | 7,209 bytes (63 objects) |
| 2.6.0-preview3 | [require (naked)](performance/require.memory.rb) | 573,572 bytes (6,616 objects) | 107,507 bytes (732 objects) |
| 2.6.0-preview3 | **[require (realistic)](performance/require_without_stdlib.memory.rb)** | 50,385 bytes (414 objects) | 7,329 bytes (63 objects) |  


## Compatibility

Ruby >= 2.5

## Copyright

Copyright (c) 2018-2019 Christophe Maximin. This software is released under the [MIT License](LICENSE.txt).

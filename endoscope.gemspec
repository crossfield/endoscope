# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'endoscope/version'

Gem::Specification.new do |spec|
  spec.name          = "endoscope"
  spec.version       = Endoscope::VERSION
  spec.authors       = ["Mathieu Ravaux"]
  spec.email         = ["mathieu.ravaux@gmail.com"]
  spec.summary       = "Remote shell for live interaction with Ruby processes"
  spec.description   = ""
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "redis"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end

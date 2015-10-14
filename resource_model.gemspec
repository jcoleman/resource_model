# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'resource_model/version'

Gem::Specification.new do |spec|
  spec.name          = "resource_model"
  spec.version       = ResourceModel::VERSION
  spec.authors       = ["James Coleman"]
  spec.email         = ["jtc331@gmail.com"]
  spec.summary       = %q{Smart models to back your resources actions.}
  spec.description   = %q{All of the goodness of ActiveModel (validations, callbacks, etc.) along with declarative typed accessors, JSON serialization, and more.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_dependency "activerecord", "~> 4.0"
end

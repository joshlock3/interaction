lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "interaction/version"

Gem::Specification.new do |spec|
  spec.name = "interaction"
  spec.version = Interaction::VERSION
  spec.authors = ["Joshua Lockhart"]
  spec.email = ["josh@objectuve.com"]

  spec.summary = "Common interface for performing complex user interactions"
  spec.homepage = ""
  spec.license = "MIT"



  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ostruct"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "standard", "~> 1.3"

  spec.required_ruby_version = ">= 3.0"
end

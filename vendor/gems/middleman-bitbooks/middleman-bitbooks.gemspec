# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

Gem::Specification.new do |s|
  s.name        = "middleman-bitbooks"
  s.version     = "0.0.1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Bryan Braun"]
  s.email       = ["email@example.com"]
  # s.homepage    = "http://example.com"
  s.summary     = "A private gem, containing Bitbooks specific features."
  s.description = "A collection of middleman extensions and other ruby code, designed to add functionality to Franklin for use with Bitbooks."

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  # The version of middleman-core your extension depends on
  s.add_runtime_dependency("middleman-core", [">= 3.3.2"])

  # Additional dependencies
  s.add_runtime_dependency("sprockets", [">= 2.12.1"])
end

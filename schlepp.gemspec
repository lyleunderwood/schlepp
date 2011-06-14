# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "schlepp/version"

Gem::Specification.new do |s|
  s.name        = "schlepp"
  s.version     = Schlepp::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Lyle Underwood"]
  s.email       = ["lyleunderwood@gmail.com"]
  s.homepage    = ""
  s.summary     = %q{Simple DSL for normalizing and importing data.}
  s.description = s.summary

  #s.rubyforge_project = "schlepp"

  s.add_runtime_dependency 'rake', '0.8.7'
  s.add_development_dependency 'rspec'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

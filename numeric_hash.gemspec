# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "numeric_hash/version"

Gem::Specification.new do |s|
  s.name        = "numeric_hash"
  s.version     = NumericHash::VERSION
  s.authors     = ["Clyde Law"]
  s.email       = ["clyde@alum.mit.edu"]
  s.homepage    = %q{http://github.com/Umofomia/numeric_hash}
  s.summary     = %q{Defines a hash whose values are Numeric or additional nested NumericHashes.}
  s.description = %q{Defines a hash whose values are Numeric or additional nested NumericHashes.}
  s.license     = 'MIT'
  
  s.add_dependency('enumerate_hash_values', '>= 0.2.0')

  s.rubyforge_project = "numeric_hash"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

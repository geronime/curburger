# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'curburger/version'

Gem::Specification.new do |s|
	s.name        = 'curburger'
	s.version     = Curburger::VERSION
	s.platform    = Gem::Platform::RUBY
	s.authors     = ['Jiri Nemecek']
	s.email       = ['nemecek.jiri@gmail.com']
	s.homepage    = ''
	s.summary     = %q{custom User-Agent}
	s.description = %q{Curburger is configurable instance based User-Agent
	                   providing get/post requests using curb.}

	s.rubyforge_project = 'curburger'

	s.files         = `git ls-files`.split("\n")
	s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
	s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
	s.require_paths = ['lib']

	s.add_dependency 'glogg'
	s.add_dependency 'curb', '~> 0.7.0'

end


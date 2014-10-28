# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chewy/version'

Gem::Specification.new do |spec|
  spec.name          = 'chewy'
  spec.version       = Chewy::VERSION
  spec.authors       = ['pyromaniac']
  spec.email         = ['kinwizard@gmail.com']
  spec.summary       = %q{Elasticsearch ODM client wrapper}
  spec.description   = %q{Chewy provides functionality for Elasticsearch index handling, documents import mappings and chainable query DSL}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.0.0'
  spec.add_development_dependency 'rspec-its', '~> 1.0.1'
  spec.add_development_dependency 'rspec-collection_matchers'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'database_cleaner'
  spec.add_development_dependency 'elasticsearch-extensions'
  spec.add_development_dependency 'rubysl', '~> 2.0' if RUBY_ENGINE == 'rbx'

  spec.add_dependency 'activesupport', '>= 3.2'
  spec.add_dependency 'elasticsearch', '>= 1.0.0'
end

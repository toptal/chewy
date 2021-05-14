lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chewy/version'

Gem::Specification.new do |spec| # rubocop:disable Metrics/BlockLength
  spec.name          = 'chewy'
  spec.version       = Chewy::VERSION
  spec.authors       = ['Toptal, LLC', 'pyromaniac']
  spec.email         = ['open-source@toptal.com', 'kinwizard@gmail.com']
  spec.summary       = 'Elasticsearch ODM client wrapper'
  spec.description   = 'Chewy provides functionality for Elasticsearch index handling, documents import mappings and chainable query DSL'
  spec.homepage      = 'https://github.com/toptal/chewy'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($RS)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'database_cleaner'
  spec.add_development_dependency 'elasticsearch-extensions'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.7.0'
  spec.add_development_dependency 'rspec-collection_matchers'
  spec.add_development_dependency 'rspec-its'
  spec.add_development_dependency 'rubocop', '1.11'
  spec.add_development_dependency 'sqlite3'
  spec.add_development_dependency 'timecop'

  spec.add_development_dependency 'method_source'
  spec.add_development_dependency 'unparser'

  spec.add_dependency 'activesupport', '>= 5.2'
  spec.add_dependency 'elasticsearch', '>= 6.3.0'
  spec.add_dependency 'elasticsearch-dsl'
  spec.add_dependency 'ruby-progressbar'
end

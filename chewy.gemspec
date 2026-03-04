lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'chewy/version'

Gem::Specification.new do |spec|
  spec.name          = 'chewy'
  spec.version       = Chewy::VERSION
  spec.authors       = ['Toptal, LLC', 'pyromaniac']
  spec.email         = ['open-source@toptal.com', 'kinwizard@gmail.com']
  spec.summary       = 'Elasticsearch ODM client wrapper'
  spec.description   = 'Chewy provides functionality for Elasticsearch index handling, documents import mappings and chainable query DSL'
  spec.homepage      = 'https://github.com/toptal/chewy'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.2'

  spec.files         = Dir['CHANGELOG.md', 'LICENSE.txt', 'README.md', 'lib/**/*']
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 7.2'
  spec.add_dependency 'elasticsearch', '>= 8.14', '< 9.0'
  spec.add_dependency 'elasticsearch-dsl'
  spec.metadata['rubygems_mfa_required'] = 'true'
end

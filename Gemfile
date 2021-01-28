source 'https://rubygems.org'

gemspec

gem 'activerecord'
# gem 'mongoid'
# gem 'sequel'

gem 'activejob', require: false
gem 'resque', require: false
gem 'sidekiq', require: false

gem 'aws-sdk-sqs', require: false
gem 'shoryuken', require: false

gem 'kaminari-core', require: false
gem 'will_paginate', require: false

gem 'parallel', require: false
gem 'ruby-progressbar', require: false

gem 'guard'
gem 'guard-rspec'

gem 'redcarpet'
gem 'yard'

eval(File.read('gemfiles/ruby3.gemfile'), nil, 'gemfiles/ruby3.gemfile') if RUBY_VERSION >= '3.0.0' # rubocop:disable Security/Eval

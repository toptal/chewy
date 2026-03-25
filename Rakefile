require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'elasticsearch/extensions/test/cluster/tasks'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :es do
  desc 'Start the elasticsearch test server'
  task :start do
    Rake.application['elasticsearch:start'].invoke
  end

  desc 'Stop the elasticsearch test server'
  task :stop do
    Rake.application['elasticsearch:stop'].invoke
  end
end

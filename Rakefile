require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :es do
  task :start do
    require 'elasticsearch/extensions/test/cluster'
    Elasticsearch::Extensions::Test::Cluster.start
  end

  task :stop do
    require 'elasticsearch/extensions/test/cluster'
    Elasticsearch::Extensions::Test::Cluster.stop
  end
end

require 'tasks/rake_helper'
namespace :chewy do
  include RakeHelper
  desc 'Destroy, recreate and import data to specified index'
  task :reset, [:index] => :environment do |task, args|
    subscribe_task_stats!
    args[:index].present? ? reset_index(args[:index]) : reset_all
  end

  namespace :reset do
    desc 'Destroy, recreate and import data for all found indexes'
    task all: :environment do
      subscribe_task_stats!
      reset_all
    end
  end

  desc 'Updates data specified index'
  task :update, [:index] => :environment do |task, args|
    subscribe_task_stats!
    args[:index].present? ? update_index(args[:index]) : update_all
  end

  namespace :update do
    desc 'Updates data for all found indexes'
    task all: :environment do
      subscribe_task_stats!
      update_all
    end
  end
end

require 'tasks/rake_helper'
namespace :chewy do
  desc 'Destroy, recreate and import data to specified index'
  task :reset, [:index] => :environment do |task, args|
    RakeHelper.subscribe_task_stats!
    args[:index].present? ? RakeHelper.reset_index(args[:index]) : RakeHelper.reset_all
  end

  namespace :reset do
    desc 'Destroy, recreate and import data for all found indexes'
    task all: :environment do
      RakeHelper.subscribe_task_stats!
      RakeHelper.reset_all
    end
  end

  desc 'Updates data specified index'
  task :update, [:index] => :environment do |task, args|
    RakeHelper.subscribe_task_stats!
    args[:index].present? ? RakeHelper.update_index(args[:index]) : RakeHelper.update_all
  end

  namespace :update do
    desc 'Updates data for all found indexes'
    task all: :environment do
      RakeHelper.subscribe_task_stats!
      RakeHelper.update_all
    end
  end
end

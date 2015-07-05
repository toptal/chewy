require 'chewy/rake_helper'

namespace :chewy do
  desc 'Destroy, recreate and import data to specified index'
  task :reset, [:index] => :environment do |task, args|
    Chewy::RakeHelper.subscribe_task_stats!

    if args[:index].present?
      Chewy::RakeHelper.reset_index(args[:index])
    else
      Chewy::RakeHelper.reset_all
    end
  end

  namespace :reset do
    desc 'Destroy, recreate and import data for all found indexes'
    task all: :environment do
      Chewy::RakeHelper.subscribe_task_stats!
      Chewy::RakeHelper.reset_all
    end
  end

  desc 'Updates data specified index'
  task :update, [:index] => :environment do |task, args|
    Chewy::RakeHelper.subscribe_task_stats!

    if args[:index].present?
      Chewy::RakeHelper.update_index(args[:index])
    else
      Chewy::RakeHelper.update_all
    end
  end

  namespace :update do
    desc 'Updates data for all found indexes'
    task all: :environment do
      Chewy::RakeHelper.subscribe_task_stats!
      Chewy::RakeHelper.update_all
    end
  end
end

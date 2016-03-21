require 'chewy/rake_helper'

namespace :chewy do
  desc 'Destroy, recreate and import data to specified index'
  task reset: :environment do |_task, args|
    Chewy::RakeHelper.subscribed_task_stats do
      indexes = args.extras

      if indexes.empty? || indexes.first.tr!(?-, '')
        Chewy::RakeHelper.reset_all(indexes)
      else
        Chewy::RakeHelper.reset_index(indexes)
      end
    end
  end

  desc 'Updates data specified index'
  task update: :environment do |_task, args|
    Chewy::RakeHelper.subscribed_task_stats do
      indexes = args.extras

      if indexes.empty? || indexes.first.tr!(?-, '')
        Chewy::RakeHelper.update_all(indexes)
      else
        Chewy::RakeHelper.update_index(indexes)
      end
    end
  end
end

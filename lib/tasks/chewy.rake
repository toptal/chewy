require 'chewy/rake_helper'

def transform_args(args)
  if args.present? && args.first.tr!('-', '')
    {except: args}
  else
    {only: args}
  end
end

namespace :chewy do
  desc 'This taks resets all the indexes with the specification changed and synchronizes the rest of them'
  task deploy: :environment do
    processed = Chewy::RakeHelper.upgrade
    Chewy::RakeHelper.sync(except: processed)
  end

  desc 'Destroy, recreate and import data for the specified indexes or all of them'
  task reset: :environment do |_task, args|
    Chewy::RakeHelper.reset(transform_args(args.extras))
  end

  desc 'Resets data for the specified indexes or all of them only if the index specification is changed'
  task upgrade: :environment do |_task, args|
    Chewy::RakeHelper.upgrade(transform_args(args.extras))
  end

  desc 'Updates data for the specified types or all of them'
  task update: :environment do |_task, args|
    Chewy::RakeHelper.update(transform_args(args.extras))
  end

  desc 'Synchronizes data for the specified types or all of them'
  task sync: :environment do |_task, args|
    Chewy::RakeHelper.sync(transform_args(args.extras))
  end

  desc 'Applies changes that were done from specified moment (as a timestamp)'
  task apply_changes_from: :environment do |_task, args|
    Chewy::RakeHelper.subscribed_task_stats do
      params = args.extras

      if params.empty?
        puts 'Please specify a timestamp like chewy:apply_changes_from[1469528705]'
      else
        timestamp, retries = params
        time = Time.at(timestamp.to_i)
        Chewy::Journal::Apply.since(time, retries: (retries.to_i if retries))
      end
    end
  end

  desc 'Cleans journal index. It accepts timestamp until which journal will be cleaned'
  task clean_journal: :environment do |_task, args|
    timestamp = args.extras.first
    if timestamp
      Chewy::Journal::Clean.until(Time.at(timestamp.to_i))
    else
      Chewy::Journal.delete!
    end
  end
end

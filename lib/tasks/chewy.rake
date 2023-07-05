require 'chewy/rake_helper'

def parse_classes(args)
  if args.present? && args.first.tr!('-', '')
    {except: args}
  else
    {only: args}
  end
end

def parse_parallel_args(args)
  options = {}
  options[:parallel] = args.first =~ /\A\d+\z/ ? Integer(args.shift) : true
  options.merge!(parse_classes(args))
end

def parse_journal_args(args)
  options = {}
  options[:time] = Time.parse(args.shift) if args.first =~ /\A\d+/
  options.merge!(parse_classes(args))
end

namespace :chewy do
  desc 'Destroys, recreates and imports data for the specified indexes or all of them'
  task reset: :environment do |_task, args|
    Chewy::RakeHelper.reset(**parse_classes(args.extras))
  end

  desc 'Resets data for the specified indexes or all of them only if the index specification is changed'
  task upgrade: :environment do |_task, args|
    Chewy::RakeHelper.upgrade(**parse_classes(args.extras))
  end

  desc 'Updates data for the specified indexes/types or all of them'
  task update: :environment do |_task, args|
    Chewy::RakeHelper.update(**parse_classes(args.extras))
  end

  desc 'Synchronizes data for the specified indexes/types or all of them'
  task sync: :environment do |_task, args|
    Chewy::RakeHelper.sync(**parse_classes(args.extras))
  end

  desc 'Resets all the indexes with the specification changed and synchronizes the rest of them'
  task deploy: :environment do
    processed = Chewy::RakeHelper.upgrade
    Chewy::RakeHelper.sync(except: processed)
  end

  desc 'Reindex data from source index to destination index'
  task :reindex, %i[source dest] => :environment do |_task, args|
    Chewy::RakeHelper.reindex(source: args[:source], dest: args[:dest])
  end

  desc 'Update mapping of exising index with body hash'
  task :update_mapping, %i[index_name] => :environment do |_task, args|
    Chewy::RakeHelper.update_mapping(name: args[:index_name])
  end

  namespace :parallel do
    desc 'Parallel version of `rake chewy:reset`'
    task reset: :environment do |_task, args|
      Chewy::RakeHelper.reset(**parse_parallel_args(args.extras))
    end

    desc 'Parallel version of `rake chewy:upgrade`'
    task upgrade: :environment do |_task, args|
      Chewy::RakeHelper.upgrade(**parse_parallel_args(args.extras))
    end

    desc 'Parallel version of `rake chewy:update`'
    task update: :environment do |_task, args|
      Chewy::RakeHelper.update(**parse_parallel_args(args.extras))
    end

    desc 'Parallel version of `rake chewy:sync`'
    task sync: :environment do |_task, args|
      Chewy::RakeHelper.sync(**parse_parallel_args(args.extras))
    end

    desc 'Parallel version of `rake chewy:deploy`'
    task deploy: :environment do |_task, args|
      parallel = args.extras.first =~ /\A\d+\z/ ? Integer(args.extras.first) : true
      processed = Chewy::RakeHelper.upgrade(parallel: parallel)
      Chewy::RakeHelper.sync(except: processed, parallel: parallel)
    end
  end

  namespace :journal do
    desc 'Create manually journal, useful when `skip_journal_creation_on_import` is used'
    task create: :environment do |_task, _args|
      Chewy::RakeHelper.journal_create
    end

    desc 'Applies changes that were done after the specified time for the specified indexes/types or all of them'
    task apply: :environment do |_task, args|
      Chewy::RakeHelper.journal_apply(**parse_journal_args(args.extras))
    end

    desc 'Removes journal records created before the specified timestamp for the specified indexes/types or all of them'
    task clean: :environment do |_task, args|
      delete_options = Chewy::RakeHelper.delete_by_query_options_from_env(ENV)
      Chewy::RakeHelper.journal_clean(
        **[
          parse_journal_args(args.extras),
          {delete_by_query_options: delete_options}
        ].reduce({}, :merge)
      )
    end
  end
end

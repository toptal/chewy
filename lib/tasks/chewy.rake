def subscribe_task_stats!
  ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
    duration = ((finish - start).to_f * 100).round / 100.0
    puts "  Imported #{payload[:type]} for #{duration}s, documents total: #{payload[:import].try(:[], :index).to_i}"
    payload[:errors].each do |action, errors|
      puts "    #{action.to_s.humanize} errors:"
      errors.each do |error, documents|
        puts "      `#{error}`"
        puts "        on #{documents.count} documents: #{documents}"
      end
    end if payload[:errors]
  end
end

def eager_load_chewy!
  dirs = Chewy::Railtie.all_engines.map { |engine| engine.paths['app/chewy'].existent }.flatten.uniq

  dirs.each do |dir|
    Dir.glob(File.join(dir, '**/*.rb')).each do |file|
      require_dependency file
    end
  end
end

def normalize_index index
  "#{index.to_s.gsub(/index$/i, '').camelize}Index".constantize
end

def reset_index index
  index = normalize_index(index)
  puts "Resetting #{index}"
  index.reset! (Time.now.to_f * 1000).round
end

def reset_all
  eager_load_chewy!
  Chewy::Index.descendants.each { |index| reset_index index }
end

def update_index index
  index = normalize_index(index)
  puts "Updating #{index}"
  if index.exists?
    index.import
  else
    puts "Index `#{index.index_name}` does not exists. Use rake chewy:reset[#{index.index_name}] to create and update it."
  end
end

def update_all
  eager_load_chewy!
  Chewy::Index.descendants.each { |index| update_index index }
end

namespace :chewy do
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

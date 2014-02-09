def subscribe_task_stats!
  ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
    duration = ((finish - start).to_f * 100).round / 100.0
    puts "  Imported #{payload[:type]} for #{duration}s, documents total: #{payload[:import]}"
    payload[:errors].each do |action, errors|
      puts "    #{action.to_s.humanize} errors:"
      errors.each do |error, documents|
        puts "      `#{error}`"
        puts "        on #{documents.count} documents: #{documents}"
      end
    end if payload[:errors]
  end
end

namespace :chewy do
  desc 'Destroy, recreate and import data to specified index'
  task :reset, [:index] => :environment do |task, args|
    subscribe_task_stats!
    "#{args[:index].camelize}Index".constantize.reset! (Time.now.to_f * 1000).round
  end

  namespace :reset do
    desc 'Destroy, recreate and import data for all found indexes'
    task all: :environment do
      subscribe_task_stats!
      Rails.application.config.paths['app/chewy'].existent.each do |dir|
        Dir.glob(File.join(dir, '**/*.rb')).each { |file| require file }
      end

      Chewy::Index.descendants.each do |index|
        puts "Resetting #{index}"
        index.reset! (Time.now.to_f * 1000).round
      end
    end
  end

  desc 'Updates data specified index'
  task :update, [:index] => :environment do |task, args|
    subscribe_task_stats!
    index = "#{args[:index].camelize}Index".constantize
    raise "Index `#{index.index_name}` does not exists. Use rake chewy:reset[#{index.index_name}] to create and update it." unless index.exists?
    index.import
  end

  namespace :update do
    desc 'Updates data for all found indexes'
    task all: :environment do
      subscribe_task_stats!
      Rails.application.config.paths['app/chewy'].existent.each do |dir|
        Dir.glob(File.join(dir, '**/*.rb')).each { |file| require file }
      end

      Chewy::Index.descendants.each do |index|
        puts "Updating #{index}"
        puts "Index `#{index.index_name}` does not exists. Use rake chewy:reset[#{index.index_name}] to create and update it." unless index.exists?
        index.import
      end
    end
  end
end

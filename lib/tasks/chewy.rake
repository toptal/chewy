namespace :chewy do
  namespace :reset do
    desc 'Destroy, recreate and import data for all found indexes'
    task all: :environment do
      Rails.application.config.paths['app/chewy'].existent.each do |dir|
        Dir.glob(File.join(dir, '**/*.rb')).each { |file| require file }
      end

      Chewy::Index.descendants.each do |index|
        puts "Resetting #{index}"
        index.reset
      end
    end
  end

  desc 'Destroy, recreate and import data to specified index'
  task :reset, [:index] => :environment do |task, args|
    "#{args[:index].camelize}Index".constantize.reset
  end

  desc 'Updates specified index'
  task :update, [:index] => :environment do |task, args|
    index = "#{args[:index].camelize}Index".constantize
    raise "Index `#{index.index_name}` does not exists. Use rake chewy:reset[index] to create and update it." unless index.index_exists?
    index.import
  end
end

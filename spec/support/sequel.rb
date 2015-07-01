require 'database_cleaner'

DB = Sequel.sqlite

DB.create_table :cities do
  primary_key :id
  column :country_code, Integer
  column :name, String
  column :rating, Integer
end

DB.create_table :countries do
  column :code, Integer, primary_key: true
  column :name, String
  column :rating, Integer
end

module SequelClassHelpers
  extend ActiveSupport::Concern

  def stub_model(name, &block)
    stub_class(name, Sequel::Model, &block).tap do |klass|
      # Sequel doesn't work well with dynamically created classes,
      # so we must set the dataset (table) name manually.
      klass.dataset = name.to_s.pluralize.to_sym
    end
  end
end

RSpec.configure do |config|
  config.include SequelClassHelpers

  config.filter_run_excluding :active_record
  config.filter_run_excluding :mongoid

  config.before(:suite) do
    DatabaseCleaner.clean_with :truncation
    DatabaseCleaner.strategy = :truncation
  end

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end

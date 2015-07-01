require 'database_cleaner'

DB = Sequel.sqlite

DB.create_table :countries do
  primary_key :id
  column :name, :string
  column :country_code, :string
  column :rating, :integer
end

DB.create_table :cities do
  primary_key :id
  column :country_id, :integer
  column :name, :string
  column :rating, :integer
end

module SequelClassHelpers
  extend ActiveSupport::Concern

  def stub_model(name, &block)
    stub_class(name, Sequel::Model, &block).tap do |klass|

      # Sequel doesn't work well with dynamically created classes,
      # so we must set the dataset (table) name manually.
      klass.dataset = name.to_s.pluralize.to_sym

      # Allow to set primary key using mass assignment.
      klass.unrestrict_primary_key
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

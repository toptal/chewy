require 'bundler'
Bundler.require

require 'active_record'
require 'database_cleaner'
require 'support/fail_helpers'
require 'support/class_helpers'

require 'chewy/rspec'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')

ActiveRecord::Schema.define do
  create_table :countries do |t|
    t.column :name, :string
    t.column :rating, :integer
  end

  create_table :cities do |t|
    t.column :country_id, :integer
    t.column :name, :string
    t.column :rating, :integer
  end
end

Kaminari::Hooks.init

Chewy.client_options = { port: 9250 }

RSpec.configure do |config|
  config.mock_with :rspec

  config.before(:suite) do
    DatabaseCleaner.clean_with :truncation
    DatabaseCleaner.strategy = :transaction
  end

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end

  config.include FailHelpers
  config.include ClassHelpers
end

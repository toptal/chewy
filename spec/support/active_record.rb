require 'database_cleaner'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
ActiveRecord::Base.logger = Logger.new('/dev/null')

ActiveRecord::Schema.define do
  create_table :countries do |t|
    t.column :name, :string
    t.column :country_code, :string
    t.column :rating, :integer
  end

  create_table :cities do |t|
    t.column :country_id, :integer
    t.column :name, :string
    t.column :rating, :integer
  end
end

module ActiveRecordClassHelpers
  extend ActiveSupport::Concern

  def stub_model name, superclass = nil, &block
    stub_class(name, superclass || ActiveRecord::Base, &block)
  end

  def active_record?
    true
  end

  def mongoid?
    false
  end
end

RSpec.configure do |config|
  config.include ActiveRecordClassHelpers

  config.filter_run_excluding :mongoid

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
end

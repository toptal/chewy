# frozen_string_literal: true

require 'database_cleaner'

ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:', pool: 10)
ActiveRecord::Base.logger = Logger.new('/dev/null')
if ActiveRecord::Base.respond_to?(:raise_in_transactional_callbacks)
  ActiveRecord::Base.raise_in_transactional_callbacks = true
end

def create_countries_table
  create_table :countries do |t|
    t.column :name, :string
    t.column :country_code, :string
    t.column :rating, :integer
    t.column :updated_at, :datetime
  end
end

def create_cities_table
  create_table :cities do |t|
    t.column :country_id, :integer
    t.column :name, :string
    t.column :historical_name, :string
    t.column :description, :string
    t.column :rating, :integer
    t.column :updated_at, :datetime
  end
end

def create_locations_table
  create_table :locations do |t|
    t.column :city_id, :integer
    t.column :lat, :string
    t.column :lon, :string
  end
end

def create_comments_table
  create_table :comments do |t|
    t.column :content, :string
    t.column :comment_type, :string
    t.column :commented_id, :integer
    t.column :updated_at, :datetime
  end
end

def create_users_table
  create_table :users, id: false do |t|
    t.column :id, :string
    t.column :name, :string
  end
end

ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS 'countries'")
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS 'cities'")
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS 'locations'")
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS 'comments'")
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS 'users'")
ActiveRecord::Schema.define do
  create_countries_table
  create_cities_table
  create_locations_table
  create_comments_table
  create_users_table
end

module ActiveRecordClassHelpers
  extend ActiveSupport::Concern

  def adapter
    :active_record
  end

  def expects_db_queries(&block)
    have_queries = false
    ActiveSupport::Notifications.subscribed(
      ->(*_) { have_queries = true },
      'sql.active_record',
      &block
    )
    raise 'Expected some db queries, but none were made' unless have_queries
  end

  def expects_no_query(except: nil, &block)
    queries = []
    ActiveSupport::Notifications.subscribed(
      ->(*args) { queries << args[4][:sql] },
      'sql.active_record',
      &block
    )
    ofending_queries = except ? queries.find_all { |query| !query.match(except) } : queries
    if ofending_queries.present?
      raise "Expected no DB queries, but the following ones were made: #{ofending_queries.join(', ')}"
    end
  end

  def stub_model(name, superclass = nil, &block)
    stub_class(name, superclass || ActiveRecord::Base, &block)
  end

  def stub_uuid_model(name, superclass = nil, &block)
    stub_class(name, superclass || ActiveRecord::Base) do
      before_create { self.id = SecureRandom.uuid }
      define_singleton_method(:primary_key, -> { 'id' })
      class_eval(&block)
    end
  end
end

RSpec.configure do |config|
  config.include ActiveRecordClassHelpers

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

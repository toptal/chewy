require 'database_cleaner'

CONFIG = {
  sessions: {
    default: {
      uri: 'mongodb://127.0.0.1:27017/chewy_mongoid_test'
    }
  }
}

Mongoid.configure do |config|
  config.load_configuration(CONFIG)
end

Mongoid.logger = Logger.new('/dev/null')

module MongoidClassHelpers
  extend ActiveSupport::Concern

  module Country
    extend ActiveSupport::Concern

    included do
      include Mongoid::Document

      field :name, type: String
      field :country_code, type: String
      field :rating, type: Integer
    end
  end

  module City
    extend ActiveSupport::Concern

    included do
      include Mongoid::Document

      field :name, type: String
      field :rating, type: Integer
    end
  end

  def stub_model name, superclass = nil, &block
    mixin = "MongoidClassHelpers::#{name.to_s.camelize}".safe_constantize || Mongoid::Document
    superclass ||= Class.new do
      include mixin
      store_in collection: name.to_s.tableize
    end

    stub_class(name, superclass, &block)
  end

  def active_record?
    false
  end

  def mongoid?
    true
  end
end

RSpec.configure do |config|
  config.include MongoidClassHelpers

  config.filter_run_excluding :active_record

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

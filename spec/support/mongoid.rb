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

  def stub_model name, superclass = nil, &block
    model = name.to_s.camelize.constantize rescue nil

    if model
      model.class_eval(&block) if block
      model
    else
      klass = if superclass && superclass.ancestors.include?(Mongoid::Document)
        superclass
      else
        Class.new(*([superclass].compact)) do
          include Mongoid::Document
          store_in collection: name.to_s.tableize
        end
      end

      stub_class(name, klass, &block)
    end
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
    Object.send(:remove_const, :City) if defined? City
    Object.send(:remove_const, :Country) if defined? Country

    class Country
      include Mongoid::Document

      field :name, type: String
      field :country_code, type: String
      field :rating, type: Integer

      has_many :cities, order: :id.asc
    end

    class City
      include Mongoid::Document

      field :name, type: String
      field :rating, type: Integer

      belongs_to :country
    end

    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end

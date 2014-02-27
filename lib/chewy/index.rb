require 'chewy/index/actions'
require 'chewy/index/aliases'
require 'chewy/index/search'
require 'chewy/index/settings'

module Chewy
  class Index
    include Actions
    include Aliases
    include Search

    singleton_class.delegate :client, to: 'Chewy'

    class_attribute :type_hash
    self.type_hash = {}

    class_attribute :_settings
    self._settings = Chewy::Index::Settings.new

    # Setups or returns ElasticSearch index name
    #
    #   class UsersIndex < Chewy::Index
    #   end
    #   UsersIndex.index_name # => 'users'
    #
    #   class UsersIndex < Chewy::Index
    #     index_name 'dudes'
    #   end
    #   UsersIndex.index_name # => 'dudes'
    #
    def self.index_name(suggest = nil)
      if suggest
        @index_name = build_index_name(suggest, prefix: Chewy.client_options[:prefix])
      else
        @index_name ||= begin
          build_index_name(
            name.gsub(/Index\Z/, '').demodulize.underscore,
            prefix: Chewy.client_options[:prefix]
          ) if name
        end
      end
      @index_name or raise UndefinedIndex
    end

    # Defines type for the index. Arguments depends on adapter used. For
    # ActiveRecord you can pass model or scope and options
    #
    #   class CarsIndex < Chewy::Index
    #     define_type Car do
    #       ...
    #     end # defines VehiclesIndex::Car type
    #   end
    #
    # Type name might be passed in complicated cases:
    #
    #   class VehiclesIndex < Chewy::Index
    #     define_type Vehicle.cars.includes(:manufacturer), name: 'cars' do
    #        ...
    #     end # defines VehiclesIndex::Cars type
    #
    #     define_type Vehicle.motocycles.includes(:manufacturer), name: 'motocycles' do
    #        ...
    #     end # defines VehiclesIndex::Motocycles type
    #   end
    #
    # For plain objects:
    #
    #   class PlanesIndex < Chewy::Index
    #     define_type :plane do
    #       ...
    #     end # defines PlanesIndex::Plane type
    #   end
    #
    # The main difference between using plain objects or ActiveRecord models for indexing
    # is import. If you will call `CarsIndex::Car.import` - it will import all the cars
    # automatically, while `PlanesIndex::Plane.import(my_planes)` requires import data to be
    # passed.
    #
    def self.define_type(target, options = {}, &block)
      type_class = Chewy::Type.new(self, target, options, &block)
      self.type_hash = type_hash.merge(type_class.type_name => type_class)

      class_eval <<-METHOD, __FILE__, __LINE__ + 1
        def self.#{type_class.type_name}
          type_hash['#{type_class.type_name}']
        end
      METHOD
    end

    # Types method has double usage.
    # If no arguments are passed - it returns array of defined types:
    #
    #   UsersIndex.types # => [UsersIndex::Admin, UsersIndex::Manager, UsersIndex::User]
    #
    # If arguments are passed it treats like a part of chainable query dsl and
    # adds types array for index to select.
    #
    #   UsersIndex.filters { name =~ 'ro' }.types(:admin, :manager)
    #   UsersIndex.types(:admin, :manager).filters { name =~ 'ro' } # the same as the first example
    #
    def self.types *args
      if args.any?
        all.types *args
      else
        type_hash.values
      end
    end

    # Returns defined types names:
    #
    #   UsersIndex.type_names # => ['admin', 'manager', 'user']
    #
    def self.type_names
      type_hash.keys
    end

    # Used as a part of index definition DSL. Defines settings:
    #
    #   class UsersIndex < Chewy::Index
    #     settings analysis: {
    #       analyzer: {
    #         name: {
    #           tokenizer: 'standard',
    #           filter: ['lowercase', 'icu_folding', 'names_nysiis']
    #         }
    #       }
    #     }
    #   end
    #
    # See http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/indices-update-settings.html
    # for more details
    #
    # It is possible to store analyzers settings in Chewy repositories
    # and link them form index class. See `Chewy::Index::Settings` for details.
    #
    def self.settings(params)
      self._settings = Chewy::Index::Settings.new params
    end

  private

    def self.build_index_name *args
      options = args.extract_options!
      [options[:prefix], args.first || index_name, options[:suffix]].reject(&:blank?).join(?_)
    end

    def self.settings_hash
      _settings.to_hash
    end

    def self.mappings_hash
      mappings = types.map(&:mappings_hash).inject(:merge)
      mappings.present? ? {mappings: mappings} : {}
    end

    def self.index_params
      [settings_hash, mappings_hash].inject(:merge)
    end

    def self.search_index
      self
    end

    def self.search_type
      type_names
    end
  end
end

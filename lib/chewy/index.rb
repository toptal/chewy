require 'chewy/search'
require 'chewy/index/actions'
require 'chewy/index/aliases'
require 'chewy/index/settings'
require 'chewy/index/specification'
require 'elasticsearch/extensions/reindex'

module Chewy
  class Index
    include Search
    include Actions
    include Aliases

    singleton_class.delegate :client, to: 'Chewy'

    class_attribute :type_hash
    self.type_hash = {}

    class_attribute :_settings
    self._settings = Chewy::Index::Settings.new

    class << self
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
      def index_name(suggest = nil)
        raise UndefinedIndex unless _index_name(suggest)
        if suggest
          @index_name = nil
          _index_name(suggest)
        else
          @index_name ||= build_index_name(_index_name, prefix: default_prefix)
        end
      end

      def _index_name(suggest = nil)
        if suggest
          @_index_name = suggest
        elsif name
          @_index_name ||= name.sub(/Index\Z/, '').demodulize.underscore
        end
        @_index_name
      end

      def derivable_index_name
        @_derivable_index_name ||= name.sub(/Index\Z/, '').underscore
      end

      # Setups or returns pure Elasticsearch index name
      # without any prefixes/suffixes
      def default_prefix
        Chewy.configuration[:prefix]
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
      def define_type(target, options = {}, &block)
        type_class = Chewy.create_type(self, target, options, &block)
        self.type_hash = type_hash.merge(type_class.type_name => type_class)
      end

      # Types method has double usage.
      # If no arguments are passed - it returns array of defined types:
      #
      #   UsersIndex.types # => [UsersIndex::Admin, UsersIndex::Manager, UsersIndex::User]
      #
      # If arguments are passed it treats like a part of chainable query DSL and
      # adds types array for index to select.
      #
      #   UsersIndex.filters { name =~ 'ro' }.types(:admin, :manager)
      #   UsersIndex.types(:admin, :manager).filters { name =~ 'ro' } # the same as the first example
      #
      def types(*args)
        if args.present?
          all.types(*args)
        else
          type_hash.values
        end
      end

      # Returns defined types names:
      #
      #   UsersIndex.type_names # => ['admin', 'manager', 'user']
      #
      def type_names
        type_hash.keys
      end

      # Returns named type:
      #
      #    UserIndex.type('admin') # => UsersIndex::Admin
      #
      def type(type_name)
        type_hash.fetch(type_name) { raise UndefinedType, "Unknown type in #{name}: #{type_name}" }
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
      def settings(params = {}, &block)
        self._settings = Chewy::Index::Settings.new(params, &block)
      end

      # Returns list of public class methods defined in current index
      #
      def scopes
        public_methods - Chewy::Index.public_methods
      end

      def journal?
        types.any?(&:journal?)
      end

      def build_index_name(*args)
        options = args.extract_options!
        [options[:prefix], args.first || index_name, options[:suffix]].reject(&:blank?).join('_')
      end

      def settings_hash
        _settings.to_hash
      end

      def mappings_hash
        mappings = types.map(&:mappings_hash).inject(:merge)
        mappings.present? ? {mappings: mappings} : {}
      end

      # Returns a hash containing the index settings and mappings
      # Used for the ES index creation as body.
      #
      # @see Chewy::Index::Specification
      # @return [Hash] specification as a hash
      def specification_hash
        [settings_hash, mappings_hash].inject(:merge)
      end

      def index_params
        ActiveSupport::Deprecation.warn '`Chewy::Index.index_params` is deprecated and will be removed soon, use `Chewy::Index.specification_hash`'
        specification_hash
      end

      # @see Chewy::Index::Specification
      # @return [Chewy::Index::Specification] a specification object instance for this particular index
      def specification
        @specification ||= Specification.new(self)
      end
    end
  end
end

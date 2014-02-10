require 'chewy/index/actions'
require 'chewy/index/aliases'
require 'chewy/index/search'

module Chewy
  class Index
    include Actions
    include Aliases
    include Search

    singleton_class.delegate :client, to: 'Chewy'

    class_attribute :type_hash
    self.type_hash = {}

    class_attribute :_settings
    self._settings = {}

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

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{type_class.type_name}
          type_hash['#{type_class.type_name}']
        end
      RUBY
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
    def self.settings(params)
      self._settings = params
    end

    def self.add_analysis_setting(group, name, options)
      self._settings = self._settings.dup
      self._settings[:analysis] ||= {}
      self._settings[:analysis][group.to_sym] ||= {}
      self._settings[:analysis][group.to_sym][name.to_sym] = options
    end

    def self.add_analyzer(name, options)
      add_analysis_setting :analyzer, name, options
    end

    def self.add_filter(name, options)
      add_analysis_setting :filter, name, options
    end

    def self.add_char_filter(name, options)
      add_analysis_setting :char_filter, name, options
    end

    def self.add_tokenizer(name, options)
      add_analysis_setting :tokenizer, name, options
    end

    # Perform import operation for every defined type
    #
    #   UsersIndex.import
    #   UsersIndex.import refresh: false # to disable index refreshing after import
    #   UsersIndex.import suffix: Time.now.to_i # imports data to index with specified suffix if such is exists
    #   UsersIndex.import batch_size: 300 # import batch size
    #
    def self.import options = {}
      objects = options.extract!(*type_names.map(&:to_sym))
      types.map do |type|
        args = [objects[type.type_name.to_sym], options.dup].reject(&:blank?)
        type.import *args
      end.all?
    end

  private

    def self.build_index_name *args
      options = args.extract_options!
      [options[:prefix], args.first || index_name, options[:suffix]].reject(&:blank?).join(?_)
    end

    def self.settings_hash
      _settings.present? ? {settings: _settings} : {}
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

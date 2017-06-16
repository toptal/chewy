require 'chewy/search'
require 'chewy/type/mapping'
require 'chewy/type/wrapper'
require 'chewy/type/observe'
require 'chewy/type/actions'
require 'chewy/type/crutch'
require 'chewy/type/import'
require 'chewy/type/witchcraft'
require 'chewy/type/adapter/object'
require 'chewy/type/adapter/active_record'
require 'chewy/type/adapter/mongoid'
require 'chewy/type/adapter/sequel'

module Chewy
  class Type
    IMPORT_OPTIONS_KEYS = %i[batch_size bulk_size refresh consistency replication raw_import journal].freeze

    include Search
    include Mapping
    include Wrapper
    include Observe
    include Actions
    include Crutch
    include Witchcraft
    include Import

    singleton_class.delegate :index_name, :_index_name, :derivable_index_name, :client, to: :index

    class_attribute :_default_import_options
    self._default_import_options = {}

    class << self
      # Chewy index current type belongs to. Defined inside `Chewy.create_type`
      #
      def index
        raise NotImplementedError
      end

      # Current type adapter. Defined inside `Chewy.create_type`, derived from
      # `Chewy::Index.define_type` arguments.
      #
      def adapter
        raise NotImplementedError
      end

      # Returns type name string
      #
      def type_name
        adapter.type_name
      end

      # Returns index and type names as a string identifier
      #
      def full_name
        @full_name ||= [index_name, type_name].join('#')
      end

      # Returns list of public class methods defined in current type
      #
      def scopes
        public_methods - Chewy::Type.public_methods
      end

      def default_import_options(params)
        params.assert_valid_keys(IMPORT_OPTIONS_KEYS)
        self._default_import_options = _default_import_options.merge(params)
      end

      def method_missing(method, *args, &block)
        if index.scopes.include?(method)
          define_singleton_method method do |*method_args, &method_block|
            all.scoping { index.public_send(method, *method_args, &method_block) }
          end
          send(method, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method, _)
        index.scopes.include?(method) || super
      end

      def const_missing(name)
        to_resolve = "#{self}::#{name}"
        to_resolve[index.to_s] = ''

        @__resolved_constants ||= {}

        if to_resolve.empty? || @__resolved_constants[to_resolve]
          super
        else
          @__resolved_constants[to_resolve] = true
          to_resolve.constantize
        end
      rescue NotImplementedError
        super
      end

      def journal?
        _default_import_options.fetch(:journal) { Chewy.configuration[:journal] }
      end
    end
  end
end

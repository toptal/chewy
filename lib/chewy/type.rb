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
    IMPORT_OPTIONS_KEYS = [:batch_size, :bulk_size, :refresh, :consistency, :replication, :raw_import, :journal]

    include Search
    include Mapping
    include Wrapper
    include Observe
    include Actions
    include Crutch
    include Witchcraft
    include Import

    singleton_class.delegate :index_name, :_index_name, :client, to: :index

    class_attribute :_default_import_options
    self._default_import_options = {}

    # Chewy index current type belongs to. Defined inside `Chewy.create_type`
    #
    def self.index
      raise NotImplementedError
    end

    # Current type adapter. Defined inside `Chewy.create_type`, derived from
    # `Chewy::Index.define_type` arguments.
    #
    def self.adapter
      raise NotImplementedError
    end

    # Returns type name string
    #
    def self.type_name
      adapter.type_name
    end

    # Returns list of public class methods defined in current type
    #
    def self.scopes
      public_methods - Chewy::Type.public_methods
    end

    def self.default_import_options(params)
      params.assert_valid_keys(IMPORT_OPTIONS_KEYS)
      self._default_import_options = _default_import_options.merge(params)
    end

    def self.method_missing(method, *args, &block)
      if index.scopes.include?(method)
        define_singleton_method method do |*method_args, &method_block|
          all.scoping { index.public_send(method, *method_args, &method_block) }
        end
        send(method, *args, &block)
      else
        super
      end
    end

    def self.const_missing(name)
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
  end
end

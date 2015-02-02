require 'chewy/search'
require 'chewy/type/mapping'
require 'chewy/type/wrapper'
require 'chewy/type/observe'
require 'chewy/type/actions'
require 'chewy/type/import'
require 'chewy/type/adapter/object'
require 'chewy/type/adapter/active_record'
require 'chewy/type/adapter/mongoid'

module Chewy
  class Type
    include Search
    include Mapping
    include Wrapper
    include Observe
    include Actions
    include Import

    singleton_class.delegate :client, to: :index

    # Chewy index current type blongs to. Defined inside `Chewy.create_type`
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

    def self.method_missing(method, *args, &block)
      if index.scopes.include?(method)
        define_singleton_method method do |*args, &block|
          all.scoping { index.public_send(method, *args, &block) }
        end
        send(method, *args, &block)
      end
    end

    def self.const_missing(name)
      to_resolve = "#{self.to_s}::#{name}"
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

require 'chewy/index/search'
require 'chewy/type/mapping'
require 'chewy/type/wrapper'
require 'chewy/type/observe'
require 'chewy/type/actions'
require 'chewy/type/import'
require 'chewy/type/adapter/object'
require 'chewy/type/adapter/active_record'

module Chewy
  class Type
    include Chewy::Index::Search
    include Mapping
    include Wrapper
    include Observe
    include Actions
    include Import

    singleton_class.delegate :client, to: :index

    def self.index
      raise NotImplementedError
    end

    def self.adapter
      raise NotImplementedError
    end

    def self.type_name
      adapter.type_name
    end

    def self.search_index
      index
    end

    def self.search_type
      type_name
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

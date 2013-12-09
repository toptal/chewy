require 'chewy/index/search'
require 'chewy/type/mapping'
require 'chewy/type/wrapper'
require 'chewy/type/observe'
require 'chewy/type/import'

module Chewy
  class Type
    include Chewy::Index::Search
    include Mapping
    include Wrapper
    include Observe
    include Import

    class_attribute :index

    singleton_class.delegate :client, to: :index

    def self.type_name(suggest = nil)
      if suggest
        @type_name = suggest.to_s
      else
        @type_name ||= (name.demodulize.underscore.singularize if name)
      end
      @type_name or raise UndefinedType
    end

    def self.search_index
      index
    end

    def self.search_type
      type_name
    end
  end
end

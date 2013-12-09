require 'chewy/index/actions'
require 'chewy/index/client'
require 'chewy/index/search'

module Chewy
  class Index
    include Actions
    include Client
    include Search

    class_attribute :types
    self.types = {}

    class_attribute :_settings
    self._settings = {}

    def self.define_type(type_class = nil, &block)
      if block
        name = type_class.presence || index_name.singularize
        type_class = Class.new(Chewy::Type) { type_name name }
        type_class.index = self
        type_class.class_eval &block
      else
        type_class.index = self
      end

      self.types = types.merge(type_class.type_name => type_class)

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{type_class.type_name}
          types['#{type_class.type_name}']
        end
      RUBY
    end

    def self.settings(params)
      self._settings = params
    end

    def self.index_name(suggest = nil)
      if suggest
        @index_name = suggest.to_s
      else
        @index_name ||= (name.gsub(/Index\Z/, '').demodulize.underscore if name)
      end
      @index_name or raise UndefinedIndex
    end

    def self.settings_hash
      _settings.present? ? {settings: _settings} : {}
    end

    def self.mappings_hash
      mappings = types.values.map(&:mappings_hash).inject(:merge)
      mappings.present? ? {mappings: mappings} : {}
    end

    def self.index_params
      [settings_hash, mappings_hash].inject(:merge)
    end

    def self.search_index
      self
    end

    def self.search_type
      types.keys
    end

    def self.import
      types.values.all? { |t| t.import }
    end

    def self.reset
      index_purge!
      import
    end
  end
end

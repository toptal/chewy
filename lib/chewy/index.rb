require 'chewy/index/actions'
require 'chewy/index/client'
require 'chewy/index/search'

module Chewy
  class Index
    include Actions
    include Client
    include Search

    class_attribute :type_hash
    self.type_hash = {}

    class_attribute :_settings
    self._settings = {}

    def self.define_type(name_or_scope, &block)
      type_class = Chewy::Type.new(self, name_or_scope, &block)
      self.type_hash = type_hash.merge(type_class.type_name => type_class)

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{type_class.type_name}
          type_hash['#{type_class.type_name}']
        end
      RUBY
    end

    def self.types
      type_hash.values
    end

    def self.type_names
      type_hash.keys
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

    def self.import
      types.all? { |t| t.import }
    end

    def self.reset
      purge!
      import
    end
  end
end

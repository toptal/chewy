require 'active_support/concern'
require 'active_support/core_ext'
require 'active_support/json'
require 'singleton'

require 'elasticsearch'

require 'chewy/version'
require 'chewy/errors'
require 'chewy/config'
require 'chewy/repository'
require 'chewy/index'
require 'chewy/type'
require 'chewy/query'
require 'chewy/fields/base'
require 'chewy/fields/default'
require 'chewy/fields/root'

require 'chewy/railtie' if defined?(::Rails)

ActiveSupport.on_load(:active_record) do
  extend Chewy::Type::Observe::ActiveRecordMethods
end

module Chewy
  def self.derive_type name
    return name if name.is_a?(Class) && name < Chewy::Type::Base

    index_name, type_name = name.split('#', 2)
    class_name = "#{index_name.camelize}Index"
    index = class_name.safe_constantize
    raise Chewy::UnderivableType.new("Can not find index named `#{class_name}`") unless index && index < Chewy::Index
    type = if type_name.present?
      index.type_hash[type_name] or raise Chewy::UnderivableType.new("Index `#{class_name}` doesn`t have type named `#{type_name}`")
    elsif index.types.one?
      index.types.first
    else
      raise Chewy::UnderivableType.new("Index `#{class_name}` has more than one type, please specify type via `#{index_name}#type_name`")
    end
  end

  def self.config
    Chewy::Config.instance
  end

  BUILT_IN_FILTERS = [:lowercase, :icu_folding]
  BUILT_IN_CHAR_FILTERS = []
  BUILT_IN_TOKENIZERS = []
  BUILT_IN_ANALYZERS = []

  mattr_accessor :analyzers, :tokenizers, :filters, :char_filters
  self.analyzers = Chewy::Repository.new(:analyzer, BUILT_IN_ANALYZERS)
  self.tokenizers = Chewy::Repository.new(:tokenizer, BUILT_IN_TOKENIZERS)
  self.filters = Chewy::Repository.new(:filter, BUILT_IN_FILTERS)
  self.char_filters = Chewy::Repository.new(:char_filter, BUILT_IN_CHAR_FILTERS)

  def self.analyzer(name, options=nil)
    analyzers.resolve(name, options)
  end

  def self.tokenizer(name, options=nil)
    tokenizers.resolve(name, options)
  end

  def self.filter(name, options=nil)
    filters.resolve(name, options)
  end

  def self.char_filter(name, options=nil)
    char_filters.resolve(name, options)
  end

  singleton_class.delegate *Chewy::Config.delegated, to: :config
end

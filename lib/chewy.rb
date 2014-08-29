require 'active_support'
require 'active_support/core_ext'
require 'active_support/concern'
require 'active_support/json'
require 'i18n/core_ext/hash'
require 'chewy/backports/deep_dup' unless Object.respond_to?(:deep_dup)
require 'singleton'

if ENV['PAGINATOR'] == 'kaminari'
  begin
    require 'kaminari'
  rescue LoadError
  end
end

if ENV['PAGINATOR'] == 'will_paginate'
  begin
    require 'will_paginate'
    require 'will_paginate/active_record'
  rescue LoadError
  end
end

require 'elasticsearch'

require 'chewy/version'
require 'chewy/errors'
require 'chewy/config'
require 'chewy/runtime'
require 'chewy/index'
require 'chewy/type'
require 'chewy/query'
require 'chewy/fields/base'
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

  def self.wait_for_status
    client.cluster.health wait_for_status: Chewy.configuration[:wait_for_status] if Chewy.configuration[:wait_for_status].present?
  end

  def self.config
    Chewy::Config.instance
  end

  singleton_class.delegate *Chewy::Config.delegated, to: :config
end

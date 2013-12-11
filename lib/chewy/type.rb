require 'chewy/type/base'

module Chewy
  module Type
    def self.new(index, target, options = {}, &block)
      type = Class.new(Chewy::Type::Base)

      adapter = if (target.is_a?(Class) && target < ActiveRecord::Base) || target.is_a?(::ActiveRecord::Relation)
        Chewy::Type::Adapter::ActiveRecord.new(target, options)
      else
        Chewy::Type::Adapter::Object.new(target)
      end

      index.const_set(adapter.name, type)
      type.send(:define_singleton_method, :index) { index }
      type.send(:define_singleton_method, :adapter) { adapter }

      type.class_eval &block if block
      type
    end
  end
end

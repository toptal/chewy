module ClassHelpers
  extend ActiveSupport::Concern

  def stub_model name, superclass = nil, &block
    stub_class(name, superclass || ActiveRecord::Base, &block)
  end

  def stub_index name, superclass = nil, &block
    stub_class("#{name.to_s.camelize}Index", superclass || Chewy::Index) { index_name = name }
      .tap { |i| i.class_eval(&block) if block }
  end

  def stub_class name, superclass, &block
    stub_const(name.to_s.camelize, Class.new(superclass, &block))
  end
end

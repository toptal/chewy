module ClassHelpers
  extend ActiveSupport::Concern

  def stub_model name, superclass = nil, &block
    stub_class(name, superclass || ActiveRecord::Base, &block)
  end

  # Takes [name, superclass] or [name] or [superclass]
  def index_class name = nil, superclass = nil, &block
    superclass, name = [name, nil] if name.is_a?(Class) && name < Chewy::Index

    klass = Class.new(superclass || Chewy::Index)
    klass.class_eval { index_name name } if name.present?
    klass.class_eval &block if block
    klass
  end

  def type_class name = nil, superclass = nil, &block
    superclass, name = [name, nil] if name.is_a?(Class) && name < Chewy::Type

    klass = Class.new(superclass || Chewy::Type)
    klass.class_eval { type_name name } if name.present?
    klass.class_eval &block if block
    klass
  end

  def stub_class name, superclass, &block
    stub_const(name.to_s.classify, Class.new(superclass, &block))
  end
end

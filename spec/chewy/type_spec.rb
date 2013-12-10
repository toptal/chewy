require 'spec_helper'

describe Chewy::Type do
  include ClassHelpers

  describe '.index' do
    before { stub_const('DummyType', Class.new(Chewy::Type)) }
    specify { DummyType.index.should be_nil }

    context do
      before { stub_index(:dummies) { define_type DummyType } }
      specify { DummyType.index.should == DummiesIndex }
    end

    context do
      before { stub_index(:dummies) { define_type {} } }
      specify { DummiesIndex.types.values.first.index.should == DummiesIndex }
    end
  end

  describe '.type_name' do
    specify { expect { Class.new(Chewy::Type).type_name }.to raise_error Chewy::UndefinedType }
    specify { Class.new(Chewy::Type) { type_name :mytype }.type_name.should == 'mytype' }
    specify { stub_const('MyType', Class.new(Chewy::Type)).type_name.should == 'my_type' }
  end
end

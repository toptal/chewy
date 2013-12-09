require 'spec_helper'

describe Chewy::Type do
  include ClassHelpers

  describe '.index' do
    let!(:dummy_type) { stub_const('DummyType', type_class) }
    specify { dummy_type.index.should be_nil }

    context do
      let!(:dummy_index) { index_class(:dummy_index) { define_type DummyType } }
      specify { dummy_type.index.should == dummy_index }
    end

    context do
      let!(:dummy_index) { index_class(:dummy_index) { define_type {} } }
      specify { dummy_index.types.values.first.index.should == dummy_index }
    end
  end

  describe '.type_name' do
    specify { expect { type_class.type_name }.to raise_error Chewy::UndefinedType }
    specify { type_class { type_name :mytype }.type_name.should == 'mytype' }
    specify { stub_const('MyType', type_class).type_name.should == 'my_type' }
  end
end

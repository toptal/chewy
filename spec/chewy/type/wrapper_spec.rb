require 'spec_helper'

describe Chewy::Type::Wrapper do
  include ClassHelpers

  let!(:dummy_model) { stub_const('DummyModel', Class.new) }

  let!(:dummy_type) do
    type_class do
      envelops DummyModel
    end
  end

  subject { dummy_type.new(name: 'Martin', age: 42) }

  it { should respond_to :name }
  it { should respond_to :age }
  its(:name) { should == 'Martin' }
  its(:age) { should == 42 }

  describe '#==' do
    specify { dummy_type.new(id: 42).should == dummy_type.new(id: 42) }
    specify { dummy_type.new(id: 42, age: 55).should == dummy_type.new(id: 42, age: 54) }
    specify { dummy_type.new(id: 42).should_not == dummy_type.new(id: 43) }
    specify { dummy_type.new(id: 42, age: 55).should_not == dummy_type.new(id: 43, age: 55) }
    specify { dummy_type.new(age: 55).should == dummy_type.new(age: 55) }
    specify { dummy_type.new(age: 55).should_not == dummy_type.new(age: 54) }

    specify { dummy_type.new(id: '42').should == DummyModel.new.tap { |m| m.stub(id: 42) } }
    specify { dummy_type.new(id: 42).should_not == DummyModel.new.tap { |m| m.stub(id: 43) } }

    specify { dummy_type.new(id: 42).should_not == Class.new }
  end
end

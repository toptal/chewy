require 'spec_helper'

describe Chewy::Type::Wrapper do
  before do
    stub_class(:city)
    stub_index(:cities) do
      define_type City
    end
  end

  let(:city_type) { CitiesIndex::City }

  subject { city_type.new(name: 'Martin', age: 42) }

  it { should respond_to :name }
  it { should respond_to :age }
  its(:name) { should == 'Martin' }
  its(:age) { should == 42 }

  describe '#==' do
    specify { city_type.new(id: 42).should == city_type.new(id: 42) }
    specify { city_type.new(id: 42, age: 55).should == city_type.new(id: 42, age: 54) }
    specify { city_type.new(id: 42).should_not == city_type.new(id: 43) }
    specify { city_type.new(id: 42, age: 55).should_not == city_type.new(id: 43, age: 55) }
    specify { city_type.new(age: 55).should == city_type.new(age: 55) }
    specify { city_type.new(age: 55).should_not == city_type.new(age: 54) }

    specify { city_type.new(id: '42').should == City.new.tap { |m| m.stub(id: 42) } }
    specify { city_type.new(id: 42).should_not == City.new.tap { |m| m.stub(id: 43) } }

    specify { city_type.new(id: 42).should_not == Class.new }
  end
end

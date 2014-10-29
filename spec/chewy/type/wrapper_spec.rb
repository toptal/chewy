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

  it { is_expected.to respond_to :name }
  it { is_expected.to respond_to :age }
  its(:name) { should == 'Martin' }
  its(:age) { should == 42 }

  describe '#==' do
    specify { expect(city_type.new(id: 42)).to eq(city_type.new(id: 42)) }
    specify { expect(city_type.new(id: 42, age: 55)).to eq(city_type.new(id: 42, age: 54)) }
    specify { expect(city_type.new(id: 42)).not_to eq(city_type.new(id: 43)) }
    specify { expect(city_type.new(id: 42, age: 55)).not_to eq(city_type.new(id: 43, age: 55)) }
    specify { expect(city_type.new(age: 55)).to eq(city_type.new(age: 55)) }
    specify { expect(city_type.new(age: 55)).not_to eq(city_type.new(age: 54)) }

    specify { expect(city_type.new(id: '42')).to eq(City.new.tap { |m| allow(m).to receive_messages(id: 42) }) }
    specify { expect(city_type.new(id: 42)).not_to eq(City.new.tap { |m| allow(m).to receive_messages(id: 43) }) }

    specify { expect(city_type.new(id: 42)).not_to eq(Class.new) }
  end
end

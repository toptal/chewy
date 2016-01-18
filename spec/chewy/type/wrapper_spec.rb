require 'spec_helper'

describe Chewy::Type::Wrapper do
  before do
    stub_class(:city)
    stub_index(:cities) do
      define_type City
    end
  end

  let(:city_type) { CitiesIndex::City }

  subject(:city) { city_type.new(name: 'Martin', age: 42) }

  it do
    is_expected.to respond_to(:name)
      .and respond_to(:age)
      .and have_attributes(
        name: 'Martin',
        age: 42
      )
  end

  it { expect { city.population }.to raise_error(NoMethodError) }

  context 'highlight' do
    subject(:city) do
      city_type.new(name: 'Martin', age: 42)
        .tap do |city|
          city._data = {
            'highlight' => { 'name' => ['<b>Mar</b>tin'] }
          }
        end
    end

    it do
      is_expected.to respond_to(:name_highlight)
        .and have_attributes(
          name: 'Martin',
          name_highlight: '<b>Mar</b>tin'
        )
    end
  end

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

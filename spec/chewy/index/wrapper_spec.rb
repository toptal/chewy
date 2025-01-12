# frozen_string_literal: true

require 'spec_helper'

describe Chewy::Index::Wrapper do
  before do
    stub_class(:city)
    stub_index(:cities) do
      index_scope City
    end
  end

  let(:cities_index) { CitiesIndex }

  describe '.build' do
    specify do
      expect(cities_index.build({}).attributes)
        .to eq('id' => nil, '_score' => nil, '_explanation' => nil)
    end
    specify do
      expect(cities_index.build('_source' => {name: 'Martin'}).attributes)
        .to eq('id' => nil, '_score' => nil, '_explanation' => nil, 'name' => 'Martin')
    end
    specify do
      expect(cities_index.build('_id' => 42).attributes)
        .to eq('id' => 42, '_score' => nil, '_explanation' => nil)
    end
    specify do
      expect(cities_index.build('_id' => 42, '_source' => {'id' => 43}).attributes)
        .to eq('id' => 43, '_score' => nil, '_explanation' => nil)
    end
    specify do
      expect(cities_index.build('_score' => 42, '_explanation' => {foo: 'bar'}).attributes)
        .to eq('id' => nil, '_score' => 42, '_explanation' => {foo: 'bar'})
    end
    specify do
      expect(cities_index.build('_score' => 42, 'borogoves' => {foo: 'bar'})._data)
        .to eq('_score' => 42, 'borogoves' => {foo: 'bar'})
    end
  end

  describe '#initialize' do
    subject(:city) { cities_index.new(name: 'Martin', age: 42) }

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
        cities_index.new(name: 'Martin', age: 42)
          .tap do |city|
            city._data = {
              'highlight' => {'name' => ['<b>Mar</b>tin']}
            }
          end
      end

      it do
        is_expected.to respond_to(:name_highlight)
          .and respond_to(:name_highlights)
          .and have_attributes(
            name: 'Martin',
            name_highlight: '<b>Mar</b>tin',
            name_highlights: ['<b>Mar</b>tin']
          )
      end
    end
  end

  describe '#==' do
    specify { expect(cities_index.new(id: 42)).to eq(cities_index.new(id: 42)) }
    specify { expect(cities_index.new(id: 42, age: 55)).to eq(cities_index.new(id: 42, age: 54)) }
    specify { expect(cities_index.new(id: 42)).not_to eq(cities_index.new(id: 43)) }
    specify { expect(cities_index.new(id: 42, age: 55)).not_to eq(cities_index.new(id: 43, age: 55)) }
    specify { expect(cities_index.new(age: 55)).to eq(cities_index.new(age: 55)) }
    specify { expect(cities_index.new(age: 55)).not_to eq(cities_index.new(age: 54)) }

    specify { expect(cities_index.new(id: '42')).to eq(City.new.tap { |m| allow(m).to receive_messages(id: 42) }) }
    specify { expect(cities_index.new(id: 42)).not_to eq(City.new.tap { |m| allow(m).to receive_messages(id: 43) }) }
    specify { expect(cities_index.new(id: 42)).not_to eq(Class.new) }

    context 'models', :orm do
      before do
        stub_model(:city)
        stub_index(:cities) do
          index_scope City
        end
      end
      specify { expect(cities_index.new(id: '42')).to eq(City.new.tap { |m| allow(m).to receive_messages(id: 42) }) }
      specify { expect(cities_index.new(id: 42)).not_to eq(City.new.tap { |m| allow(m).to receive_messages(id: 43) }) }
      specify { expect(cities_index.new(id: 42)).not_to eq(Class.new) }
    end
  end
end

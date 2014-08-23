require 'spec_helper'

describe Chewy::Type::Actions do
  before { Chewy.client.indices.delete index: '*' }

  before do
    stub_model(:city)
  end

  before do
    stub_index(:cities) do
      define_type City do
        field :name
      end
    end
  end

  let!(:dummy_cities) { 3.times.map { |i| City.create(name: "name#{i}") } }
  let(:city) { CitiesIndex::City }

  before do
    city.import
  end

  describe '.reset' do
    specify { expect { city.reset }.to update_index(city) }
  end
end
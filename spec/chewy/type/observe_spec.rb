require 'spec_helper'

describe Chewy::Type::Import do
  include ClassHelpers
  before { Chewy.stub(observing_enabled: true) }

  describe '.update_index' do
    before do
      stub_index(:dummies) do
        define_type {}
      end
    end

    let(:backreferenced) { 3.times.map { |i| double(id: i) } }

    specify { expect { DummiesIndex.dummy.update_index(backreferenced) }
        .to update_index(DummiesIndex.dummy).and_reindex(backreferenced) }
    specify { expect { DummiesIndex.dummy.update_index([]) }
      .not_to update_index(DummiesIndex.dummy) }
    specify { expect { DummiesIndex.dummy.update_index(nil) }
      .not_to update_index(DummiesIndex.dummy) }
  end

  context 'integration' do
    before do
      stub_model(:city) do
        belongs_to :country
        update_elasticsearch('cities#city') { self }
        update_elasticsearch('countries#country') { country }
      end

      stub_model(:country) do
        has_many :cities
        update_elasticsearch('cities#city') { cities }
        update_elasticsearch('countries#country') { self }
      end

      stub_index(:cities) do
        define_type do
          envelops(City)
        end
      end

      stub_index(:countries) do
        define_type do
          envelops(Country)
        end
      end
    end

    let(:city) { City.create!(country: Country.create!) }
    let(:country) { Country.create!(cities: 2.times.map { City.create! }) }

    specify { expect { city.save! }.to update_index(CitiesIndex.city).and_reindex(city) }
    specify { expect { city.save! }.to update_index(CountriesIndex.country).and_reindex(city.country) }
    specify { expect { country.save! }.to update_index(CitiesIndex.city).and_reindex(country.cities) }
    specify { expect { country.save! }.to update_index(CountriesIndex.country).and_reindex(country) }
  end
end

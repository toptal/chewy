require 'spec_helper'

describe Chewy::Type::Import do
  describe '.update_index' do
    before do
      stub_index(:dummies) do
        define_type :dummy
      end
    end

    let(:backreferenced) { 3.times.map { |i| double(id: i) } }

    specify { expect { DummiesIndex.dummy.update_index(backreferenced, urgent: true) }
      .to update_index('dummies#dummy', atomic: false).and_reindex(backreferenced) }
    specify { expect { DummiesIndex.dummy.update_index(backreferenced) }
      .not_to update_index('dummies#dummy', atomic: false) }
    specify { expect { DummiesIndex.dummy.update_index([]) }
      .not_to update_index('dummies#dummy') }
    specify { expect { DummiesIndex.dummy.update_index(nil) }
      .not_to update_index('dummies#dummy') }
  end

  context 'integration' do
    before do
      stub_model(:city) do
        belongs_to :country
        update_index('cities#city') { self }
        update_index 'countries#country', :country
      end

      stub_model(:country) do
        has_many :cities
        update_index('cities#city') { cities }
        update_index 'countries#country', :self, urgent: true
      end

      stub_index(:cities) do
        define_type City
      end

      stub_index(:countries) do
        define_type Country
      end
    end

    let(:city) { City.create!(country: Country.create!) }
    let(:country) { Country.create!(cities: 2.times.map { City.create! }) }

    specify { expect { city.save! }.not_to update_index('cities#city', atomic: false) }
    specify { expect { country.save! }.to update_index('countries#country').and_reindex(country) }

    context do
      specify { expect { city.save! }.to update_index('cities#city').and_reindex(city) }
      specify { expect { city.save! }.to update_index('countries#country').and_reindex(city.country) }
      specify { expect { country.save! }.to update_index('cities#city').and_reindex(country.cities) }
      specify { expect { country.save! }.to update_index('countries#country').and_reindex(country) }
    end

    context do
      let(:other_city) { City.create! }

      specify do
        expect(CitiesIndex::City).not_to receive(:import)
        [city, other_city].map(&:save!)
      end

      specify do
        expect(CitiesIndex::City).to receive(:import).with([city.id, other_city.id]).once
        Chewy.atomic { [city, other_city].map(&:save!) }
      end
    end

    context do
      let(:other_country) { Country.create! }

      specify do
        expect(CountriesIndex::Country).to receive(:import).at_least(2).times
        [country, other_country].map(&:save!)
      end

      specify do
        expect(CountriesIndex::Country).to receive(:import).with([country.id, other_country.id]).once
        Chewy.atomic { [country, other_country].map(&:save!) }
      end
    end
  end
end

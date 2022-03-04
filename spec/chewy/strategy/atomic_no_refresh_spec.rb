require 'spec_helper'

describe Chewy::Strategy::AtomicNoRefresh, :orm do
  around { |example| Chewy.strategy(:bypass) { example.run } }

  before do
    stub_model(:country) do
      update_index('countries') { self }
    end

    stub_index(:countries) do
      index_scope Country
    end
  end

  let(:country) { Country.create!(name: 'hello', country_code: 'HL') }
  let(:other_country) { Country.create!(name: 'world', country_code: 'WD') }

  specify do
    expect { [country, other_country].map(&:save!) }
      .to update_index(CountriesIndex, strategy: :atomic_no_refresh)
      .and_reindex(country, other_country).only.no_refresh
  end

  specify do
    expect { [country, other_country].map(&:destroy) }
      .to update_index(CountriesIndex, strategy: :atomic_no_refresh)
      .and_delete(country, other_country).only.no_refresh
  end

  context do
    before do
      stub_index(:countries) do
        index_scope Country
        root id: -> { country_code }
      end
    end

    specify do
      expect { [country, other_country].map(&:save!) }
        .to update_index(CountriesIndex, strategy: :atomic_no_refresh)
        .and_reindex('HL', 'WD').only.no_refresh
    end

    specify do
      expect { [country, other_country].map(&:destroy) }
        .to update_index(CountriesIndex, strategy: :atomic_no_refresh)
        .and_delete('HL', 'WD').only.no_refresh
    end

    specify do
      expect do
        country.save!
        other_country.destroy
      end
        .to update_index(CountriesIndex, strategy: :atomic_no_refresh)
        .and_reindex('HL').and_delete('WD').only.no_refresh
    end
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe Chewy::Index::Observe do
  describe '.update_index' do
    before do
      stub_index(:dummies)
    end

    let(:backreferenced) { Array.new(3) { |i| double(id: i) } }

    specify do
      expect { DummiesIndex.update_index(backreferenced) }
        .to raise_error Chewy::UndefinedUpdateStrategy
    end
    specify do
      expect { DummiesIndex.update_index([]) }
        .not_to update_index('dummies')
    end
    specify do
      expect { DummiesIndex.update_index(nil) }
        .not_to update_index('dummies')
    end
  end

  context 'integration', :orm do
    let(:update_condition) { true }

    before do
      stub_model(:city) do
        update_index(-> { 'cities' }, :self)
        update_index('countries') { changes['country_id'] || previous_changes['country_id'] || country }
      end

      stub_model(:country) do
        update_index('cities', if: -> { update_condition }) { cities }
        update_index(-> { 'countries' }, :self)
        attr_accessor :update_condition
      end

      City.belongs_to :country
      Country.has_many :cities

      stub_index(:cities) do
        index_scope City
      end

      stub_index(:countries) do
        index_scope Country
      end
    end

    context do
      let!(:country1) { Chewy.strategy(:atomic) { Country.create!(id: 1, update_condition: update_condition) } }
      let!(:country2) { Chewy.strategy(:atomic) { Country.create!(id: 2, update_condition: update_condition) } }
      let!(:city) { Chewy.strategy(:atomic) { City.create!(id: 1, country: country1) } }

      specify { expect { city.save! }.to update_index('cities').and_reindex(city).only }
      specify { expect { city.save! }.to update_index('countries').and_reindex(country1).only }

      specify { expect { city.destroy }.to update_index('cities') }
      specify { expect { city.destroy }.to update_index('countries').and_reindex(country1).only }

      specify { expect { city.update!(country: nil) }.to update_index('cities').and_reindex(city).only }
      specify { expect { city.update!(country: nil) }.to update_index('countries').and_reindex(country1).only }

      specify { expect { city.update!(country: country2) }.to update_index('cities').and_reindex(city).only }
      specify do
        expect { city.update!(country: country2) }
          .to update_index('countries').and_reindex(country1, country2).only
      end
    end

    context do
      let!(:country) do
        Chewy.strategy(:atomic) do
          cities = Array.new(2) { |i| City.create!(id: i) }
          Country.create!(id: 1, cities: cities, update_condition: update_condition)
        end
      end

      specify { expect { country.save! }.to update_index('cities').and_reindex(country.cities).only }
      specify { expect { country.save! }.to update_index('countries').and_reindex(country).only }

      specify { expect { country.destroy }.to update_index('cities').and_reindex(country.cities).only }
      specify { expect { country.destroy }.to update_index('countries') }

      context 'conditional update' do
        let(:update_condition) { false }
        specify { expect { country.save! }.not_to update_index('cities') }
        specify { expect { country.destroy }.not_to update_index('cities') }
      end
    end
  end

  context 'transactions', :active_record do
    context do
      before { stub_model(:city) { update_index 'cities', :self } }
      before { stub_index(:cities) { index_scope City } }

      specify do
        Chewy.strategy(:urgent) do
          ActiveRecord::Base.transaction do
            expect { City.create! }.not_to update_index('cities')
          end
        end
      end

      specify do
        city = Chewy.strategy(:bypass) { City.create! }

        Chewy.strategy(:urgent) do
          ActiveRecord::Base.transaction do
            expect { city.destroy }.not_to update_index('cities')
          end
        end
      end
    end

    context do
      before { allow(Chewy).to receive_messages(use_after_commit_callbacks: false) }
      before { stub_model(:city) { update_index 'cities', :self } }
      before { stub_index(:cities) { index_scope City } }

      specify do
        Chewy.strategy(:urgent) do
          ActiveRecord::Base.transaction do
            expect { City.create! }.to update_index('cities')
          end
        end
      end

      specify do
        city = Chewy.strategy(:bypass) { City.create! }

        Chewy.strategy(:urgent) do
          ActiveRecord::Base.transaction do
            expect { city.destroy }.to update_index('cities')
          end
        end
      end
    end
  end
end

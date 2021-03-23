require 'spec_helper'

describe Chewy::Type::Observe do
  describe '.update_index' do
    before do
      stub_index(:dummies) do
        define_type :dummy
      end
    end

    let(:backreferenced) { Array.new(3) { |i| double(id: i) } }

    specify do
      expect { DummiesIndex::Dummy.update_index(backreferenced) }
        .to raise_error Chewy::UndefinedUpdateStrategy
    end
    specify do
      expect { DummiesIndex::Dummy.update_index([]) }
        .not_to update_index('dummies#dummy')
    end
    specify do
      expect { DummiesIndex::Dummy.update_index(nil) }
        .not_to update_index('dummies#dummy')
    end
  end

  context 'integration', :orm do
    let(:update_condition) { true }

    before do
      city_countries_update_proc = ->(*) { changes['country_id'] || previous_changes['country_id'] || country }

      stub_model(:city) do
        update_index(->(city) { "cities##{city.class.name.underscore}" }) { self }
        update_index 'countries#country', &city_countries_update_proc
      end

      stub_model(:country) do
        update_index('cities#city', if: -> { update_condition }) { cities }
        update_index(-> { "countries##{self.class.name.underscore}" }, :self)
        attr_accessor :update_condition
      end

      City.belongs_to :country
      Country.has_many :cities

      stub_index(:cities) do
        define_type City
      end

      stub_index(:countries) do
        define_type Country
      end
    end

    context do
      let!(:country1) { Chewy.strategy(:atomic) { Country.create!(id: 1, update_condition: update_condition) } }
      let!(:country2) { Chewy.strategy(:atomic) { Country.create!(id: 2, update_condition: update_condition) } }
      let!(:city) { Chewy.strategy(:atomic) { City.create!(id: 1, country: country1) } }

      specify { expect { city.save! }.to update_index('cities#city').and_reindex(city).only }
      specify { expect { city.save! }.to update_index('countries#country').and_reindex(country1).only }

      specify { expect { city.update!(country: nil) }.to update_index('cities#city').and_reindex(city).only }
      specify { expect { city.update!(country: nil) }.to update_index('countries#country').and_reindex(country1).only }

      specify { expect { city.update!(country: country2) }.to update_index('cities#city').and_reindex(city).only }
      specify do
        expect { city.update!(country: country2) }
          .to update_index('countries#country').and_reindex(country1, country2).only
      end
    end

    context do
      let!(:country) do
        Chewy.strategy(:atomic) do
          cities = Array.new(2) { |i| City.create!(id: i) }
          Country.create!(id: 1, cities: cities, update_condition: update_condition)
        end
      end

      specify { expect { country.save! }.to update_index('cities#city').and_reindex(country.cities).only }
      specify { expect { country.save! }.to update_index('countries#country').and_reindex(country).only }

      context 'conditional update' do
        let(:update_condition) { false }
        specify { expect { country.save! }.not_to update_index('cities#city') }
      end
    end
  end

  context 'transactions', :active_record do
    context do
      before { stub_model(:city) { update_index 'cities#city', :self } }
      before { stub_index(:cities) { define_type City } }

      specify do
        Chewy.strategy(:urgent) do
          ActiveRecord::Base.transaction do
            expect { City.create! }.not_to update_index('cities#city')
          end
        end
      end
    end

    context do
      before { allow(Chewy).to receive_messages(use_after_commit_callbacks: false) }
      before { stub_model(:city) { update_index 'cities#city', :self } }
      before { stub_index(:cities) { define_type City } }

      specify do
        Chewy.strategy(:urgent) do
          ActiveRecord::Base.transaction do
            expect { City.create! }.to update_index('cities#city')
          end
        end
      end
    end
  end
end

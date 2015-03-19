require 'spec_helper'

describe Chewy::Type::Import do
  describe '.update_index' do
    before do
      stub_index(:dummies) do
        define_type :dummy
      end
    end

    let(:backreferenced) { 3.times.map { |i| double(id: i) } }

    specify { expect { DummiesIndex.dummy.update_index(backreferenced) }
      .to raise_error Chewy::UndefinedUpdateStrategy }
    specify { expect { DummiesIndex.dummy.update_index([]) }
      .not_to update_index('dummies#dummy') }
    specify { expect { DummiesIndex.dummy.update_index(nil) }
      .not_to update_index('dummies#dummy') }
  end

  context 'integration', :orm do
    before do
      stub_model(:city) do
        update_index('cities#city') { self }
        update_index 'countries#country', :country
      end

      stub_model(:country) do
        update_index('cities#city') { cities }
        update_index 'countries#country', :self
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

    let(:city) { Chewy.strategy(:atomic) { City.create!(id: 1, country: Country.create!(id: 1)) } }
    let(:country) { Chewy.strategy(:atomic) { Country.create!(id: 1, cities: 2.times.map { |i| City.create!(id: i) }) } }

    specify { expect { city.save! }.to update_index('cities#city').and_reindex(city) }
    specify { expect { city.save! }.to update_index('countries#country').and_reindex(city.country) }
    specify { expect { country.save! }.to update_index('cities#city').and_reindex(country.cities) }
    specify { expect { country.save! }.to update_index('countries#country').and_reindex(country) }

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

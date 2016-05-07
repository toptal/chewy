require 'spec_helper'

describe Chewy::Type::Crutch do
  before do
    stub_model(:city)

    stub_class(:cities_crutch) do
      def initialize type, collection
        @collection = collection.map(&:id)
      end

      def countries(id)
        "2CountryFor#{@collection.index(id)}"
      end
    end

    stub_index(:cities) do
      define_type City do
        crutch :countries do |collection|
          collection.map { |c| [c.id, "1CountryFor#{c.id}"] }.to_h
        end
        crutch CitiesCrutch

        field :country_name1, value: -> (city, crutch) { crutch.countries[city.id] }
        field :country_name2, value: -> (city, _crutch, crutch1) { crutch1.countries(city.id) }
      end
    end
  end

  let(:cities) { 2.times.map { |i| City.create! name: "City#{i}" } }

  specify { expect { CitiesIndex::City.import!(cities) }
    .to update_index(CitiesIndex::City)
    .and_reindex(cities[0], with: {country_name1: "1CountryFor#{cities[0].id}", country_name2: "2CountryFor0"})
    .and_reindex(cities[1], with: {country_name1: "1CountryFor#{cities[1].id}", country_name2: "2CountryFor1"}) }
end

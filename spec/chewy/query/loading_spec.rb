require 'spec_helper'

describe Chewy::Query::Loading do
  include ClassHelpers
  before { Chewy::Index.client.indices.delete }

  before do
    stub_model(:city)
    stub_model(:country)
  end

  context 'multiple types' do
    let(:cities) { 6.times.map { |i| City.create!(rating: i) } }
    let(:countries) { 6.times.map { |i| Country.create!(rating: i) } }

    let(:places_index) do
      index_class(:places) do
        define_type(:city) do
          envelops City
          field :rating, type: 'number', value: ->(o){ o.rating }
        end
        define_type(:country) do
          envelops Country
          field :rating, type: 'number', value: ->(o){ o.rating }
        end
      end
    end

    before do
      places_index.city.import(cities)
      places_index.country.import(countries)
    end

    specify { places_index.search.order(:rating).limit(6).load.should =~ cities.first(3) + countries.first(3) }
    specify { places_index.search.order(:rating).limit(6).load(scopes: {city: ->(i){ where('rating < 2') }})
      .should =~ cities.first(2) + countries.first(3) }
    specify { places_index.search.order(:rating).limit(6).load.total_count.should == 12 }
  end
end

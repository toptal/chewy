require 'spec_helper'

describe Chewy::Type::Import do
  before { Chewy.massacre }

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

  let!(:dummy_cities) { 3.times.map { |i| City.create(id: i + 1, name: "name#{i}") } }
  let(:city) { CitiesIndex::City }

  describe '.import', :orm do
    specify { expect(city.import).to eq(true) }
    specify { expect(city.import([])).to eq(true) }
    specify { expect(city.import(dummy_cities)).to eq(true) }
    specify { expect(city.import(dummy_cities.map(&:id))).to eq(true) }

    specify { expect { city.import([]) }.not_to update_index(city) }
    specify { expect { city.import }.to update_index(city).and_reindex(dummy_cities) }
    specify { expect { city.import dummy_cities }.to update_index(city).and_reindex(dummy_cities) }
    specify { expect { city.import dummy_cities.map(&:id) }.to update_index(city).and_reindex(dummy_cities) }

    describe 'criteria-driven importing' do
      let(:names) { %w(name0 name1) }

      context 'mongoid', :mongoid do
        specify { expect { city.import(City.where(:name.in => names)) }.to update_index(city).and_reindex(dummy_cities.first(2)) }
        specify { expect { city.import(City.where(:name.in => names).map(&:id)) }.to update_index(city).and_reindex(dummy_cities.first(2)) }
      end

      context 'active record', :active_record do
        specify { expect { city.import(City.where(name: names)) }.to update_index(city).and_reindex(dummy_cities.first(2)) }
        specify { expect { city.import(City.where(name: names).map(&:id)) }.to update_index(city).and_reindex(dummy_cities.first(2)) }
      end
    end

    specify do
      dummy_cities.first.destroy
      expect { city.import dummy_cities }
        .to update_index(city).and_reindex(dummy_cities.from(1)).and_delete(dummy_cities.first)
    end

    specify do
      dummy_cities.first.destroy
      expect { city.import dummy_cities.map(&:id) }
        .to update_index(city).and_reindex(dummy_cities.from(1)).and_delete(dummy_cities.first)
    end

    specify do
      dummy_cities.first.destroy

      expect(CitiesIndex.client).to receive(:bulk).with(hash_including(
        body: [{delete: {_id: dummy_cities.first.id}}]
      ))

      expect(CitiesIndex.client).to receive(:bulk).with(hash_including(
        body: [{index: {_id: 2, data: {'name' => "name1"}}}, {index: {_id: 3, data: {'name' => "name2"}}}]
      ))

      city.import dummy_cities.map(&:id), batch_size: 2
    end

    specify do
      expect(CitiesIndex.client).to receive(:bulk).with(hash_including(refresh: true))
      city.import dummy_cities
    end

    specify do
      expect(CitiesIndex.client).to receive(:bulk).with(hash_including(refresh: false))
      city.import dummy_cities, refresh: false
    end

    context 'scoped' do
      before do
        names = %w(name0 name1)

        criteria = if defined?(::Mongoid)
          { :name.in => names }
        else
          { name: names }
        end

        stub_index(:cities) do
          define_type City.where(criteria) do
            field :name
          end
        end
      end

      specify { expect { city.import }.to update_index(city).and_reindex(dummy_cities.first(2)) }

      context 'mongoid', :mongoid do
        specify do
          expect { city.import City.where(_id: dummy_cities.first.id) }.to update_index(city).and_reindex(dummy_cities.first).only
        end
      end

      context 'active record', :active_record do
        specify do
          expect { city.import City.where(id: dummy_cities.first.id) }.to update_index(city).and_reindex(dummy_cities.first).only
        end
      end
    end

    context 'instrumentation payload' do
      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
          outer_payload = payload
        end

        dummy_cities.first.destroy
        city.import dummy_cities
        expect(outer_payload).to eq({type: CitiesIndex::City, import: {delete: 1, index: 2}})
      end

      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
          outer_payload = payload
        end

        dummy_cities.first.destroy
        city.import dummy_cities, batch_size: 1
        expect(outer_payload).to eq({type: CitiesIndex::City, import: {delete: 1, index: 2}})
      end

      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
          outer_payload = payload
        end

        city.import dummy_cities, batch_size: 1
        expect(outer_payload).to eq({type: CitiesIndex::City, import: {index: 3}})
      end

      context do
        before do
          stub_index(:cities) do
            define_type City do
              field :name, type: 'object'
            end
          end
        end

        specify do
          outer_payload = nil
          ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
            outer_payload = payload
          end

          city.import dummy_cities, batch_size: 1
          expect(outer_payload).to eq({
            type: CitiesIndex::City,
            errors: {
              index: {
                'MapperParsingException[object mapping for [city] tried to parse as object, but got EOF, has a concrete value been provided to it?]' => ['1', '2', '3']
              }
            },
            import: {index: 3}
          })
        end
      end
    end

    context 'error handling' do
      context do
        before do
          stub_index(:cities) do
            define_type City do
              field :name, type: 'object'
            end
          end
        end

        specify { expect(city.import(dummy_cities)).to eq(false) }
        specify { expect(city.import(dummy_cities.map(&:id))).to eq(false) }
        specify { expect(city.import(dummy_cities, batch_size: 1)).to eq(false) }
      end

      context do
        before do
          stub_index(:cities) do
            define_type City do
              field :name, type: 'object', value: ->{ name == 'name1' ? name : {name: name} }
            end
          end
        end

        specify { expect(city.import(dummy_cities)).to eq(false) }
        specify { expect(city.import(dummy_cities.map(&:id))).to eq(false) }
        specify { expect(city.import(dummy_cities, batch_size: 1)).to eq(false) }
      end
    end

    context 'parent-child relationship', :orm do
      let(:country) { Country.create(id: 1, name: 'country') }
      let(:another_country) { Country.create(id: 2, name: 'another country') }

      before do
        stub_model(:country)
        stub_model(:city)
      end

      before do
        stub_index(:countries) do
          define_type Country do
            field :name
          end

          define_type City do
            root parent: { type: 'country' }, parent_id: -> { country_id } do
              field :name
            end
          end
        end
      end

      before { CountriesIndex::Country.import(country) }

      let(:child_city) { City.create(id: 4, country_id: country.id, name: 'city') }
      let(:city) { CountriesIndex::City }

      specify { expect(city.import(child_city)).to eq(true)  }
      specify { expect { city.import child_city }.to update_index(city).and_reindex(child_city) }

      specify do
        expect(CountriesIndex.client).to receive(:bulk).with(hash_including(
          body: [{ index: { _id: child_city.id, parent: country.id, data: { 'name' => 'city' } } }]
        ))

        city.import child_city
      end

      context 'updating or deleting' do
        before { city.import child_city }

        specify do
          child_city.update_attributes(country_id: another_country.id)

          expect(CountriesIndex.client).to receive(:bulk).with(hash_including(
            body: [
              { delete: { _id: child_city.id, parent: country.id.to_s } },
              { index: { _id: child_city.id, parent: another_country.id, data: { 'name' => 'city' } } }
            ]
          ))

          city.import child_city
        end

        specify do
          child_city.destroy

          expect(CountriesIndex.client).to receive(:bulk).with(hash_including(
            body: [{ delete: { _id: child_city.id, parent: country.id.to_s } }]
          ))

          city.import child_city
        end

        specify do
          child_city.destroy

          expect(CountriesIndex.client).to receive(:bulk).with(hash_including(
            body: [{ delete: { _id: child_city.id, parent: country.id.to_s } }]
          ))

          city.import child_city.id
        end
      end
    end

    context 'root id', :orm do
      let(:canada) { Country.create(id: 1, name: 'Canada', country_code: 'CA', rating: 4) }
      let(:country)  { CountriesIndex::Country }

      before do
        stub_model(:country)
      end

      before do
        stub_index(:countries) do
          define_type Country do
            root _id: -> { country_code } do
              field :name
              field :rating
            end
          end
        end
      end

      specify { expect( country.import(canada) ).to eq(true)  }
      specify { expect { country.import(canada) }.to update_index(country).and_reindex(canada.country_code) }

      specify do
        expect(CountriesIndex.client).to receive(:bulk).with(hash_including(
          body: [{ index: { _id: canada.country_code, data: { 'name' => 'Canada', 'rating' => 4 } } }]
        ))

        country.import canada
      end

      specify do
        canada.update_attributes(rating: 9)

        expect(CountriesIndex.client).to receive(:bulk).with(hash_including(
          body: [{ index: { _id: canada.country_code, data: { 'name' => 'Canada', 'rating' => 9 } } }]
        ))

        country.import canada
      end

      specify do
        canada.destroy

        expect(CountriesIndex.client).to receive(:bulk).with(hash_including(
          body: [{ delete: { _id: canada.country_code } }]
        ))

        country.import canada
      end

    end  # END root id
  end

  describe '.import!', :orm do
    specify { expect { city.import! }.not_to raise_error }

    context do
      before do
        stub_index(:cities) do
          define_type City do
            field :name, type: 'object'
          end
        end
      end

      specify { expect { city.import!(dummy_cities) }.to raise_error Chewy::ImportFailed }
    end
  end
end

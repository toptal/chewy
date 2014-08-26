require 'spec_helper'

describe Chewy::Type::Import do
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

  describe '.import' do
    specify { city.import.should eq(true) }
    specify { city.import([]).should eq(true) }
    specify { city.import(dummy_cities).should eq(true) }
    specify { city.import(dummy_cities.map(&:id)).should eq(true) }

    specify { expect { city.import([]) }.not_to update_index(city) }
    specify { expect { city.import }.to update_index(city).and_reindex(dummy_cities) }
    specify { expect { city.import dummy_cities }.to update_index(city).and_reindex(dummy_cities) }
    specify { expect { city.import dummy_cities.map(&:id) }.to update_index(city).and_reindex(dummy_cities) }
    specify { expect { city.import(City.where(name: ['name0', 'name1'])) }
      .to update_index(city).and_reindex(dummy_cities.first(2)) }
    specify { expect { city.import(City.where(name: ['name0', 'name1']).map(&:id)) }
        .to update_index(city).and_reindex(dummy_cities.first(2)) }

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
      dummy_cities.from(1).each.with_index do |c, i|
        expect(CitiesIndex.client).to receive(:bulk).with(hash_including(
          body: [{index: {_id: c.id, data: {'name' => "name#{i+1}"}}}]
        ))
      end
      city.import dummy_cities.map(&:id), batch_size: 1
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
        stub_index(:cities) do
          define_type City.where(name: ['name0', 'name1']) do
            field :name
          end
        end
      end

      specify { expect { city.import }.to update_index(city).and_reindex(dummy_cities.first(2)) }
      specify { expect { city.import City.where(id: dummy_cities.first.id) }.to update_index(city).and_reindex(dummy_cities.first).only }
    end

    context 'instrumentation payload' do
      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
          outer_payload = payload
        end

        dummy_cities.first.destroy
        city.import dummy_cities
        outer_payload.should == {type: CitiesIndex::City, import: {delete: 1, index: 2}}
      end

      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
          outer_payload = payload
        end

        dummy_cities.first.destroy
        city.import dummy_cities, batch_size: 1
        outer_payload.should == {type: CitiesIndex::City, import: {delete: 1, index: 2}}
      end

      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
          outer_payload = payload
        end

        city.import dummy_cities, batch_size: 1
        outer_payload.should == {type: CitiesIndex::City, import: {index: 3}}
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
          outer_payload.should == {
            type: CitiesIndex::City,
            errors: {
              index: {
                'MapperParsingException[object mapping for [city] tried to parse as object, but got EOF, has a concrete value been provided to it?]' => ['1', '2', '3']
              }
            },
            import: {index: 3}
          }
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

        specify { city.import(dummy_cities).should eq(false) }
        specify { city.import(dummy_cities.map(&:id)).should eq(false) }
        specify { city.import(dummy_cities, batch_size: 1).should eq(false) }
      end

      context do
        before do
          stub_index(:cities) do
            define_type City do
              field :name, type: 'object', value: ->{ name == 'name1' ? name : {name: name} }
            end
          end
        end

        specify { city.import(dummy_cities).should eq(false) }
        specify { city.import(dummy_cities.map(&:id)).should eq(false) }
        specify { city.import(dummy_cities, batch_size: 1).should eq(false) }
      end
    end

    context 'parent-child relationship' do
      let(:country) { Country.create(name: 'country') }
      let(:another_country) { Country.create(name: 'another country') }

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

      let(:child_city) { City.create(country_id: country.id, name: 'city') }
      let(:city) { CountriesIndex::City }

      specify { city.import(child_city).should eq(true)  }
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
  end

  describe '.import!' do
    specify { expect { city.import!.should }.not_to raise_error }

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

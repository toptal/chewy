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

  describe 'index creation on import' do
    let(:dummy_city) { City.create }

    specify 'lazy (default)' do
      expect(CitiesIndex).to receive(:exists?).and_call_original
      expect(CitiesIndex).to receive(:create!).and_call_original
      CitiesIndex::City.import(dummy_city)
    end

    context 'skip' do
      before do
        # To avoid flaky issues when previous specs were run
        expect(Chewy::Index).to receive(:descendants).and_return([CitiesIndex])
        Chewy.create_indices
        Chewy.config.settings[:skip_index_creation_on_import] = true
      end
      after { Chewy.config.settings[:skip_index_creation_on_import] = nil }

      specify do
        expect(CitiesIndex).not_to receive(:exists?)
        expect(CitiesIndex).not_to receive(:create!)
        CitiesIndex::City.import(dummy_city)
      end
    end
  end

  let!(:dummy_cities) { Array.new(3) { |i| City.create(id: i + 1, name: "name#{i}") } }
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

      imported = []
      allow(CitiesIndex.client).to receive(:bulk) { |params|
        imported << params[:body]
        nil
      }

      city.import dummy_cities.map(&:id), batch_size: 2
      expect(imported.flatten).to match_array([
        { index: { _id: 2, data: { 'name' => 'name1' } } },
        { index: { _id: 3, data: { 'name' => 'name2' } } },
        { delete: { _id: dummy_cities.first.id } }
      ])
    end

    context ':bulk_size' do
      specify { expect(city.import(dummy_cities.first, bulk_size: 1.2.kilobyte)).to eq(true) }
      specify { expect(city.import(dummy_cities, bulk_size: 1.2.kilobyte)).to eq(true) }
      specify { expect { city.import(dummy_cities, bulk_size: 1.2.kilobyte) }.to update_index(city).and_reindex(dummy_cities) }

      specify do
        dummy_cities.first.destroy

        imported = []
        allow(CitiesIndex.client).to receive(:bulk) { |params|
          imported << params[:body]
          nil
        }

        city.import dummy_cities.map(&:id), bulk_size: 1.2.kilobyte
        expect(imported.flatten).to match_array([
          %({"delete":{"_id":1}}\n),
          %({"index":{"_id":2}}\n{"name":"name1"}\n{"index":{"_id":3}}\n{"name":"name2"}\n)
        ])
      end

      context do
        let!(:dummy_cities) { Array.new(3) { |i| City.create(id: i + 1, name: "name#{i}" * 20) } }

        specify do
          dummy_cities.first.destroy

          imported = []
          allow(CitiesIndex.client).to receive(:bulk) { |params|
            imported << params[:body]
            nil
          }

          city.import dummy_cities.map(&:id), bulk_size: 1.2.kilobyte
          expect(imported.flatten).to match_array([
            %({"delete":{"_id":1}}\n),
            %({"index":{"_id":2}}\n{"name":"#{'name1' * 20}"}\n),
            %({"index":{"_id":3}}\n{"name":"#{'name2' * 20}"}\n)
          ])
        end

        specify do
          expect { city.import dummy_cities.map(&:id), bulk_size: 1.1.kilobyte }.to raise_error ArgumentError
        end
      end
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

        criteria = case adapter
        when :mongoid
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
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |_name, _start, _finish, _id, payload|
          outer_payload = payload
        end

        dummy_cities.first.destroy
        city.import dummy_cities
        expect(outer_payload).to eq(type: CitiesIndex::City, import: { delete: 1, index: 2 })
      end

      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |_name, _start, _finish, _id, payload|
          outer_payload = payload
        end

        dummy_cities.first.destroy
        city.import dummy_cities, batch_size: 2
        expect(outer_payload).to eq(type: CitiesIndex::City, import: { delete: 1, index: 2 })
      end

      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |_name, _start, _finish, _id, payload|
          outer_payload = payload
        end

        city.import dummy_cities, batch_size: 2
        expect(outer_payload).to eq(type: CitiesIndex::City, import: { index: 3 })
      end

      context do
        before do
          stub_index(:cities) do
            define_type City do
              field :name, type: 'object'
            end
          end
        end

        let(:mapper_parsing_exception) do
          {
            'type' => 'mapper_parsing_exception',
            'reason' => 'object mapping for [name] tried to parse field [name] as object, but found a concrete value'
          }
        end

        specify do
          outer_payload = nil
          ActiveSupport::Notifications.subscribe('import_objects.chewy') do |_name, _start, _finish, _id, payload|
            outer_payload = payload
          end

          city.import dummy_cities, batch_size: 2
          expect(outer_payload).to eq(type: CitiesIndex::City,
            errors: { index: { mapper_parsing_exception => %w(1 2 3) } },
            import: { index: 3 })
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
              field :name, type: 'object', value: -> { name == 'name1' ? name : { name: name } }
            end
          end
        end

        specify { expect(city.import(dummy_cities)).to eq(false) }
        specify { expect(city.import(dummy_cities.map(&:id))).to eq(false) }
        specify { expect(city.import(dummy_cities, batch_size: 2)).to eq(false) }
      end
    end

    context 'parent-child relationship', :orm do
      let(:country) { Country.create(id: 1, name: 'country') }
      let(:another_country) { Country.create(id: 2, name: 'another country') }

      before do
        stub_model(:country)
        stub_model(:city)
        adapter == :sequel ? City.many_to_one(:country) : City.belongs_to(:country)
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

      specify { expect(city.import(child_city)).to eq(true) }
      specify { expect { city.import child_city }.to update_index(city).and_reindex(child_city) }

      specify do
        expect(CountriesIndex.client).to receive(:bulk)
          .with(hash_including(body: [{ index: { _id: child_city.id, parent: country.id, data: { 'name' => 'city' } } }]))

        city.import child_city
      end

      context 'updating or deleting' do
        before { city.import child_city }

        specify do
          child_city.update_attributes(country_id: another_country.id)

          expect(CountriesIndex.client).to receive(:bulk).with(
            hash_including(
              body: [
                { delete: { _id: child_city.id, parent: country.id.to_s } },
                { index: { _id: child_city.id, parent: another_country.id, data: { 'name' => 'city' } } }
              ]
            )
          )

          city.import child_city
        end

        specify do
          child_city.destroy

          expect(CountriesIndex.client).to receive(:bulk)
            .with(hash_including(body: [{ delete: { _id: child_city.id, parent: country.id.to_s } }]))

          city.import child_city
        end

        specify do
          child_city.destroy

          expect(CountriesIndex.client).to receive(:bulk).with(hash_including(
                                                                 body: [{ delete: { _id: child_city.id, parent: country.id.to_s } }]
          ))

          city.import child_city.id
        end

        specify do
          child_city.destroy

          expect(city.import(child_city)).to eq(true)
          expect(city.import(child_city)).to eq(true)
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

      specify { expect(country.import(canada)).to eq(true) }
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
    end

    context 'default_import_options is set' do
      before do
        CitiesIndex::City.default_import_options(batch_size: 500, bulk_size: 1.megabyte)
      end

      specify do
        expect(CitiesIndex::City.adapter).to receive(:import).with(batch_size: 500, bulk_size: 1.megabyte)
        CitiesIndex::City.import
      end
    end
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

    context 'when .import fails' do
      before do
        allow(city).to receive(:import) { raise }
      end

      specify do
        expect(ActiveSupport::Notifications).to receive(:unsubscribe)
        begin
          city.import!(dummy_cities)
        rescue
          nil
        end
      end
    end
  end
end

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
      let(:names) { %w[name0 name1] }

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
        {index: {_id: 2, data: {'name' => 'name1'}}},
        {index: {_id: 3, data: {'name' => 'name2'}}},
        {delete: {_id: dummy_cities.first.id}}
      ])
    end

    context ':bulk_size' do
      let!(:dummy_cities) { Array.new(3) { |i| City.create(id: i + 1, name: "name#{i}" * 20) } }

      specify { expect { city.import(dummy_cities, bulk_size: 1.2.kilobyte) }.to update_index(city).and_reindex(dummy_cities) }

      context do
        before { expect(Chewy.client).to receive(:bulk).exactly(3).times.and_call_original }
        specify { expect(city.import(dummy_cities, bulk_size: 1.2.kilobyte)).to eq(true) }
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
        names = %w[name0 name1]

        criteria = case adapter
        when :mongoid
          {:name.in => names}
        else
          {name: names}
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
        expect(outer_payload).to eq(type: CitiesIndex::City, import: {delete: 1, index: 2})
      end

      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |_name, _start, _finish, _id, payload|
          outer_payload = payload
        end

        dummy_cities.first.destroy
        city.import dummy_cities, batch_size: 2
        expect(outer_payload).to eq(type: CitiesIndex::City, import: {delete: 1, index: 2})
      end

      specify do
        outer_payload = nil
        ActiveSupport::Notifications.subscribe('import_objects.chewy') do |_name, _start, _finish, _id, payload|
          outer_payload = payload
        end

        city.import dummy_cities, batch_size: 2
        expect(outer_payload).to eq(type: CitiesIndex::City, import: {index: 3})
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
            errors: {index: {mapper_parsing_exception => %w[1 2 3]}},
            import: {index: 3})
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
              field :name, type: 'object', value: -> { name == 'name1' ? name : {name: name} }
            end
          end
        end

        specify { expect(city.import(dummy_cities)).to eq(false) }
        specify { expect(city.import(dummy_cities.map(&:id))).to eq(false) }
        specify { expect(city.import(dummy_cities, batch_size: 2)).to eq(false) }
      end
    end

    context 'default_import_options are set' do
      before do
        CitiesIndex::City.default_import_options(batch_size: 500)
      end

      specify do
        expect(CitiesIndex::City.adapter).to receive(:import).with(hash_including(batch_size: 500))
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

require 'spec_helper'

describe Chewy::Type::Import do
  include ClassHelpers

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
    specify { city.import.should be_true }
    specify { city.import([]).should be_true }
    specify { city.import(dummy_cities).should be_true }
    specify { city.import(dummy_cities.map(&:id)).should be_true }

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
    end
  end
end

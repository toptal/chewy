describe Chewy::Journal do
  context 'journaling', orm: true do
    before do
      stub_model(:city) do
        update_index 'places#city', :self
      end
      stub_model(:country) do
        update_index 'places#country', :self
      end

      stub_index(:places) do
        define_type City do
          default_import_options journal: true
        end
        define_type Country do
          default_import_options journal: true
        end
      end

      Chewy.massacre
      begin
        Chewy.client.indices.delete(index: Chewy::Journal.index_name)
      rescue Elasticsearch::Transport::Transport::Errors::NotFound
      end
      Timecop.freeze(time)
    end

    after do
      Timecop.return
    end

    let(:time) { Time.now }
    let(:import_time) { time + 1 }
    let(:update_time) { time + 2 }
    let(:destroy_time) { time + 3 }

    def timestamp(time)
      time.to_i
    end

    specify do
      Chewy.strategy(:urgent) do
        cities = Array.new(2) { |i| City.create!(id: i + 1) }
        countries = Array.new(2) { |i| Country.create!(id: i + 1) }
        Country.create!(id: 3)

        Timecop.freeze(import_time)
        PlacesIndex.import

        expect(Chewy.client.indices.exists?(index: Chewy::Journal.index_name)).to eq true

        Timecop.freeze(update_time)
        cities.first.update_attributes!(name: 'Supername')

        Timecop.freeze(destroy_time)
        countries.last.destroy

        journal_records = Chewy.client.search(index: Chewy::Journal.index_name, type: Chewy::Journal.type_name, sort: 'created_at')['hits']['hits'].map { |r| r['_source'] }

        expected_journal = [
          {
            'index_name' => 'places',
            'type_name' => 'city',
            'action' => 'index',
            'object_ids' => [1],
            'created_at' => time.to_i
          },
          {
            'index_name' => 'places',
            'type_name' => 'city',
            'action' => 'index',
            'object_ids' => [2],
            'created_at' => time.to_i
          },
          {
            'index_name' => 'places',
            'type_name' => 'country',
            'action' => 'index',
            'object_ids' => [1],
            'created_at' => time.to_i
          },
          {
            'index_name' => 'places',
            'type_name' => 'country',
            'action' => 'index',
            'object_ids' => [2],
            'created_at' => time.to_i
          },
          {
            'index_name' => 'places',
            'type_name' => 'country',
            'action' => 'index',
            'object_ids' => [3],
            'created_at' => time.to_i
          },
          {
            'index_name' => 'places',
            'type_name' => 'city',
            'action' => 'index',
            'object_ids' => [1, 2],
            'created_at' => import_time.to_i
          },
          {
            'index_name' => 'places',
            'type_name' => 'country',
            'action' => 'index',
            'object_ids' => [1, 2, 3],
            'created_at' => import_time.to_i
          },
          {
            'index_name' => 'places',
            'type_name' => 'city',
            'action' => 'index',
            'object_ids' => [1],
            'created_at' => update_time.to_i
          },
          {
            'index_name' => 'places',
            'type_name' => 'country',
            'action' => 'delete',
            'object_ids' => [2],
            'created_at' => destroy_time.to_i
          }
        ]

        expect(Chewy.client.count(index: Chewy::Journal.index_name)['count']).to eq 9
        expect(journal_records).to eq expected_journal
        expect(Chewy::Journal.entries_from(import_time).length).to eq 4

        # simulate lost data
        Chewy.client.delete(index: 'places', type: 'city', id: 1, refresh: true)
        expect(PlacesIndex::City.all.to_a.length).to eq 1

        Chewy::Journal.apply_changes_from(time)
        expect(PlacesIndex::City.all.to_a.length).to eq 2

        Chewy::Journal.clean_until(import_time)
        expect(Chewy.client.count(index: Chewy::Journal.index_name)['count']).to eq 2

        Chewy::Journal.delete!
        expect(Chewy.client.count(index: Chewy::Journal.index_name)['count']).to eq 0
      end
    end
  end
end

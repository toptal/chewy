require 'spec_helper'

describe Chewy::Journal do
  context 'journaling', :orm do
    ['', 'namespace/'].each do |namespace|
      context namespace.present? ? 'with namespace' : 'without namespace' do
        before do
          stub_model(:city) do
            update_index "#{namespace}cities", :self
          end
          stub_model(:country) do
            update_index "#{namespace}countries", :self
          end

          stub_index("#{namespace}cities") do
            index_scope City
            default_import_options journal: true
          end
          stub_index("#{namespace}countries") do
            index_scope Country
            default_import_options journal: true
          end

          drop_indices
          Chewy.settings[:prefix] = 'some_prefix'
          Timecop.freeze(time)
        end

        after do
          Chewy.settings[:prefix] = nil
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
          cities_index = namespace.present? ? Namespace::CitiesIndex : CitiesIndex
          countries_index = namespace.present? ? Namespace::CountriesIndex : CountriesIndex
          Chewy.strategy(:urgent) do
            cities = Array.new(2) { |i| City.create!(id: i + 1) }
            countries = Array.new(2) { |i| Country.create!(id: i + 1) }
            Country.create!(id: 3)

            Timecop.freeze(import_time)

            cities_index.import
            countries_index.import

            expect(Chewy::Stash::Journal.exists?).to eq true

            Timecop.freeze(update_time)
            cities.first.update!(name: 'Supername')

            Timecop.freeze(destroy_time)
            countries.last.destroy

            journal_entries = Chewy::Stash::Journal.order(:created_at).hits.map { |r| r['_source'] }
            expected_journal = [
              {
                'index_name' => "#{namespace}cities",
                'action' => 'index',
                'references' => ['1'].map(&Base64.method(:encode64)),
                'created_at' => time.utc.as_json
              },
              {
                'index_name' => "#{namespace}cities",
                'action' => 'index',
                'references' => ['2'].map(&Base64.method(:encode64)),
                'created_at' => time.utc.as_json
              },
              {
                'index_name' => "#{namespace}countries",
                'action' => 'index',
                'references' => ['1'].map(&Base64.method(:encode64)),
                'created_at' => time.utc.as_json
              },
              {
                'index_name' => "#{namespace}countries",
                'action' => 'index',
                'references' => ['2'].map(&Base64.method(:encode64)),
                'created_at' => time.utc.as_json
              },
              {
                'index_name' => "#{namespace}countries",
                'action' => 'index',
                'references' => ['3'].map(&Base64.method(:encode64)),
                'created_at' => time.utc.as_json
              },
              {
                'index_name' => "#{namespace}cities",
                'action' => 'index',
                'references' => %w[1 2].map(&Base64.method(:encode64)),
                'created_at' => import_time.utc.as_json
              },
              {
                'index_name' => "#{namespace}countries",
                'action' => 'index',
                'references' => %w[1 2 3].map(&Base64.method(:encode64)),
                'created_at' => import_time.utc.as_json
              },
              {
                'index_name' => "#{namespace}cities",
                'action' => 'index',
                'references' => ['1'].map(&Base64.method(:encode64)),
                'created_at' => update_time.utc.as_json
              },
              {
                'index_name' => "#{namespace}countries",
                'action' => 'delete',
                'references' => ['2'].map(&Base64.method(:encode64)),
                'created_at' => destroy_time.utc.as_json
              }
            ]

            expect(Chewy::Stash::Journal.count).to eq 9
            expect(journal_entries).to eq expected_journal

            journal_entries = Chewy::Stash::Journal.entries(import_time - 1)
            expect(journal_entries.size).to eq 4

            # simulate lost data
            Chewy.client.delete(index: "#{Chewy.settings[:prefix]}_cities", id: 1, refresh: true)
            expect(cities_index.count).to eq 1

            described_class.new.apply(time)
            expect(cities_index.count).to eq 2

            clean_response = described_class.new.clean(import_time)
            expect(clean_response['deleted'] || clean_response['_indices']['_all']['deleted']).to eq 7
            Chewy.client.indices.refresh
            expect(Chewy::Stash::Journal.count).to eq 2

            Timecop.return
          end
        end
      end
    end
  end

  context do
    before { drop_indices }
    before do
      stub_model(:city) do
        update_index 'cities', :self
      end
      stub_model(:country) do
        update_index 'countries', :self
      end

      stub_index(:cities) do
        index_scope City
        default_import_options journal: true
      end
      stub_index(:countries) do
        index_scope Country
        default_import_options journal: true
      end
    end

    describe '#apply' do
      specify { expect(described_class.new(CitiesIndex).apply(2.minutes.ago)).to eq(0) }

      context 'with an index filter' do
        let(:time) { Time.now }

        before { Timecop.freeze(time) }
        after { Timecop.return }

        specify do
          Chewy.strategy(:urgent) do
            Array.new(2) { |i| City.create!(id: i + 1) }
            Array.new(2) { |i| Country.create!(id: i + 1) }

            # simulate lost data
            Chewy.client.delete(index: 'cities', id: 1, refresh: true)
            Chewy.client.delete(index: 'countries', id: 1, refresh: true)
            expect(CitiesIndex.all.to_a.length).to eq 1
            expect(CountriesIndex.all.to_a.length).to eq 1

            # Replay on specific index
            expect(described_class.new(CitiesIndex).apply(time)).to eq(2)
            expect(CitiesIndex.all.to_a.length).to eq 2
            expect(CountriesIndex.all.to_a.length).to eq 1

            # Replay on both
            Chewy.client.delete(index: 'cities', id: 1, refresh: true)
            expect(CitiesIndex.all.to_a.length).to eq 1
            expect(described_class.new(CitiesIndex, CountriesIndex).apply(time)).to eq(4)
            expect(CitiesIndex.all.to_a.length).to eq 2
            expect(CountriesIndex.all.to_a.length).to eq 2
          end
        end
      end

      context 'when order is not preserved' do
        let(:time) { Time.now }

        it 'paginates properly through all items' do
          Chewy.strategy(:urgent) do
            Timecop.travel(time + 1.minute) { City.create!(id: 2) }
            Timecop.travel(time + 3.minute) { City.create!(id: 4) }
            Timecop.travel(time + 2.minute) { City.create!(id: 1) }
            Timecop.travel(time + 4.minute) { City.create!(id: 3) }
          end

          CitiesIndex.purge!
          expect(CitiesIndex.all.to_a.length).to eq 0

          # Replay on specific index
          expect(described_class.new(CitiesIndex).apply(time, fetch_limit: 2)).to eq(4)
          expect(CitiesIndex.all.to_a.map(&:id).sort).to eq([1, 2, 3, 4])
        end
      end
    end
  end
end

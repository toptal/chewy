require 'spec_helper'

describe Chewy::Journal do
  context 'journaling', orm: true do
    ['', 'namespace/'].each do |namespace|
      context namespace.present? ? 'with namespace' : 'without namespace' do
        before do
          stub_model(:city) do
            update_index "#{namespace}places#city", :self
          end
          stub_model(:country) do
            update_index "#{namespace}places#country", :self
          end

          stub_index("#{namespace}places") do
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
            nil
          end
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
          places_index = namespace.present? ? Namespace::PlacesIndex : PlacesIndex
          Chewy.strategy(:urgent) do
            cities = Array.new(2) { |i| City.create!(id: i + 1) }
            countries = Array.new(2) { |i| Country.create!(id: i + 1) }
            Country.create!(id: 3)

            Timecop.freeze(import_time)

            places_index.import

            expect(Chewy.client.indices.exists?(index: Chewy::Journal.index_name)).to eq true

            Timecop.freeze(update_time)
            cities.first.update_attributes!(name: 'Supername')

            Timecop.freeze(destroy_time)
            countries.last.destroy

            journal_records = Chewy.client.search(index: Chewy::Journal.index_name, type: Chewy::Journal.type_name, sort: 'created_at')['hits']['hits'].map { |r| r['_source'] }

            expected_journal = [
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'city',
                'action' => 'index',
                'object_ids' => [1],
                'created_at' => time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'city',
                'action' => 'index',
                'object_ids' => [2],
                'created_at' => time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'country',
                'action' => 'index',
                'object_ids' => [1],
                'created_at' => time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'country',
                'action' => 'index',
                'object_ids' => [2],
                'created_at' => time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'country',
                'action' => 'index',
                'object_ids' => [3],
                'created_at' => time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'city',
                'action' => 'index',
                'object_ids' => [1, 2],
                'created_at' => import_time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'country',
                'action' => 'index',
                'object_ids' => [1, 2, 3],
                'created_at' => import_time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'city',
                'action' => 'index',
                'object_ids' => [1],
                'created_at' => update_time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'country',
                'action' => 'delete',
                'object_ids' => [2],
                'created_at' => destroy_time.to_i
              }
            ]

            expect(Chewy.client.count(index: Chewy::Journal.index_name)['count']).to eq 9
            expect(journal_records).to eq expected_journal

            journal_entries = Chewy::Journal.entries_from(import_time)
            expect(journal_entries.length).to eq 4
            # we have only 2 types, so we can group all journal entries(4) into 2
            expect(Chewy::Journal.group(journal_entries)).to eq [
              Chewy::Journal::Entry.new('index_name' => "#{namespace}places",
                                        'type_name' => 'city',
                                        'action' => nil,
                                        'object_ids' => [1, 2],
                                        'created_at' => nil),
              Chewy::Journal::Entry.new('index_name' => "#{namespace}places",
                                        'type_name' => 'country',
                                        'action' => 'delete',
                                        'object_ids' => [1, 2, 3],
                                        'created_at' => destroy_time.to_i)
            ]

            # simulate lost data
            Chewy.client.delete(index: "#{Chewy.settings[:prefix]}_places", type: 'city', id: 1, refresh: true)
            expect(places_index::City.all.to_a.length).to eq 1

            Chewy::Journal.apply_changes_from(time)
            expect(places_index::City.all.to_a.length).to eq 2

            expect(Chewy::Journal.clean_until(import_time)).to eq 7
            expect(Chewy.client.count(index: Chewy::Journal.index_name)['count']).to eq 2

            expect(Chewy::Journal.delete!).to be_truthy
            expect { Chewy::Journal.delete! }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound)
            expect(Chewy::Journal.delete).to eq false
            expect(Chewy::Journal.exists?).to eq false
          end
        end
      end
    end

    context '.apply_changes_from with an index filter' do
      let(:time) { Time.now }

      before do
        stub_model(:city) do
          update_index 'city', :self
        end
        stub_model(:country) do
          update_index 'country', :self
        end

        stub_index('city') do
          define_type City do
            default_import_options journal: true
          end
        end
        stub_index('country') do
          define_type Country do
            default_import_options journal: true
          end
        end

        Chewy.massacre
        Timecop.freeze(time)
      end

      specify do
        Chewy.strategy(:urgent) do
          Array.new(2) { |i| City.create!(id: i + 1) }
          Array.new(2) { |i| Country.create!(id: i + 1) }
          expect(CityIndex.all.to_a.length).to eq 2
          expect(CountryIndex.all.to_a.length).to eq 2

          # simulate lost data
          Chewy.client.delete(index: 'city', type: 'city', id: 1, refresh: true)
          Chewy.client.delete(index: 'country', type: 'country', id: 1, refresh: true)
          expect(CityIndex.all.to_a.length).to eq 1
          expect(CountryIndex.all.to_a.length).to eq 1

          # Replay on specific index
          Chewy::Journal.new(CityIndex).apply_changes_from(time)
          expect(CityIndex.all.to_a.length).to eq 2
          expect(CountryIndex.all.to_a.length).to eq 1
        end
      end
    end
  end
end

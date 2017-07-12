require 'spec_helper'

describe Chewy::Journal do
  context 'journaling', :orm do
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

            expect(Chewy::Stash.exists?).to eq true

            Timecop.freeze(update_time)
            cities.first.update_attributes!(name: 'Supername')

            Timecop.freeze(destroy_time)
            countries.last.destroy

            journal_entries = Chewy::Stash::Journal.order(:created_at).hits.map { |r| r['_source'] }
            expected_journal = [
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'city',
                'action' => 'index',
                'references' => ['1'],
                'created_at' => time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'city',
                'action' => 'index',
                'references' => ['2'],
                'created_at' => time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'country',
                'action' => 'index',
                'references' => ['1'],
                'created_at' => time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'country',
                'action' => 'index',
                'references' => ['2'],
                'created_at' => time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'country',
                'action' => 'index',
                'references' => ['3'],
                'created_at' => time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'city',
                'action' => 'index',
                'references' => %w[1 2],
                'created_at' => import_time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'country',
                'action' => 'index',
                'references' => %w[1 2 3],
                'created_at' => import_time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'city',
                'action' => 'index',
                'references' => ['1'],
                'created_at' => update_time.to_i
              },
              {
                'index_name' => "#{namespace}places",
                'type_name' => 'country',
                'action' => 'delete',
                'references' => ['2'],
                'created_at' => destroy_time.to_i
              }
            ]

            expect(Chewy::Stash::Journal.count).to eq 9
            expect(journal_entries).to eq expected_journal

            journal_entries = Chewy::Stash::Journal.entries(import_time)
            expect(journal_entries.size).to eq 4
            # we have only 2 types, so we can group all journal entries(4) into 2
            grouped_attributes = Chewy::Journal::Apply.group(journal_entries).map do |e|
              e.attributes.except('id', '_score', '_explanation')
            end
            expect(grouped_attributes).to eq [{
              'index_name' => "#{namespace}places",
              'type_name' => 'city',
              'action' => 'index',
              'references' => %w[1 2],
              'created_at' => update_time.to_i
            }, {
              'index_name' => "#{namespace}places",
              'type_name' => 'country',
              'action' => 'index',
              'references' => %w[1 2 3],
              'created_at' => destroy_time.to_i
            }]

            # simulate lost data
            Chewy.client.delete(index: "#{Chewy.settings[:prefix]}_places", type: 'city', id: 1, refresh: true)
            expect(places_index::City.count).to eq 1

            Chewy::Journal::Apply.since(time)
            expect(places_index::City.count).to eq 2

            clean_response = Chewy::Stash::Journal.clean(import_time)
            expect(clean_response['deleted'] || clean_response['_indices']['_all']['deleted']).to eq 7
            Chewy.client.indices.refresh
            expect(Chewy::Stash::Journal.count).to eq 2

            Timecop.return
          end
        end
      end
    end
  end
end

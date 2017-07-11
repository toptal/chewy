require 'spec_helper'

describe Chewy::Journal::Apply do
  describe '.since' do
    context 'with an index filter' do
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

      after { Timecop.return }

      specify do
        Chewy.strategy(:urgent) do
          Array.new(2) { |i| City.create!(id: i + 1) }
          Array.new(2) { |i| Country.create!(id: i + 1) }

          # simulate lost data
          Chewy.client.delete(index: 'city', type: 'city', id: 1, refresh: true)
          Chewy.client.delete(index: 'country', type: 'country', id: 1, refresh: true)
          expect(CityIndex.all.to_a.length).to eq 1
          expect(CountryIndex.all.to_a.length).to eq 1

          # Replay on specific index
          described_class.since(time, only: [CityIndex])
          expect(CityIndex.all.to_a.length).to eq 2
          expect(CountryIndex.all.to_a.length).to eq 1

          # Replay on both
          Chewy.client.delete(index: 'city', type: 'city', id: 1, refresh: true)
          expect(CityIndex.all.to_a.length).to eq 1
          described_class.since(time, only: [CityIndex, CountryIndex])
          expect(CityIndex.all.to_a.length).to eq 2
          expect(CountryIndex.all.to_a.length).to eq 2
        end
      end
    end

    context 'retries' do
      let(:time) { Time.now.to_i }
      before do
        stub_model(:city) do
          update_index 'city', :self
        end
        stub_index('city') do
          define_type City do
            default_import_options journal: true
          end
        end
        Chewy.massacre
        Timecop.freeze
        Chewy.strategy(:urgent)
        City.create!(id: 1)
      end

      after do
        Chewy.strategy.pop
        Timecop.return
      end

      specify 'journal was cleaned after the first call' do
        expect(Chewy::Journal::Entry)
          .to receive(:since).exactly(2).and_call_original
        Chewy::Journal::Apply.since(time)
      end

      context 'endless journal' do
        let(:count_of_checks) { 10 } # default
        let!(:journal_entries) do
          record = Chewy::Journal::Entry.since(time).first
          Array.new(count_of_checks) do |i|
            Chewy::Stash::Journal.new(
              record.attributes.merge(
                'created_at' => time.to_i + i,
                'object_ids' => [i]
              )
            )
          end
        end

        specify '10 retries by default' do
          expect(Chewy::Journal::Entry)
            .to receive(:since).exactly(count_of_checks) { [journal_entries.shift].compact }
          Chewy::Journal::Apply.since(time)
        end

        specify 'with :once parameter set' do
          expect(Chewy::Journal::Entry)
            .to receive(:since).exactly(1) { [journal_entries.shift].compact }
          Chewy::Journal::Apply.since(time, once: true)
        end

        context 'with retries parameter set' do
          let(:retries) { 5 }

          specify do
            expect(Chewy::Journal::Entry)
              .to receive(:since).exactly(retries) { [journal_entries.shift].compact }
            Chewy::Journal::Apply.since(time, retries: retries)
          end
        end
      end
    end
  end
end

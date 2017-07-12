require 'spec_helper'

describe Chewy::Journal::Apply do
  before { Chewy.massacre }
  before do
    stub_model(:city) do
      update_index 'cities', :self
    end
    stub_model(:country) do
      update_index 'countries', :self
    end

    stub_index(:cities) do
      define_type City do
        default_import_options journal: true
      end
    end
    stub_index(:countries) do
      define_type Country do
        default_import_options journal: true
      end
    end
  end

  describe '.since' do
    context 'with an index filter' do
      let(:time) { Time.now }

      before { Timecop.freeze(time) }
      after { Timecop.return }

      specify do
        Chewy.strategy(:urgent) do
          Array.new(2) { |i| City.create!(id: i + 1) }
          Array.new(2) { |i| Country.create!(id: i + 1) }

          # simulate lost data
          Chewy.client.delete(index: 'cities', type: 'city', id: 1, refresh: true)
          Chewy.client.delete(index: 'countries', type: 'country', id: 1, refresh: true)
          expect(CitiesIndex.all.to_a.length).to eq 1
          expect(CountriesIndex.all.to_a.length).to eq 1

          # Replay on specific index
          described_class.since(time, only: [CitiesIndex])
          expect(CitiesIndex.all.to_a.length).to eq 2
          expect(CountriesIndex.all.to_a.length).to eq 1

          # Replay on both
          Chewy.client.delete(index: 'cities', type: 'city', id: 1, refresh: true)
          expect(CitiesIndex.all.to_a.length).to eq 1
          described_class.since(time, only: [CitiesIndex, CountriesIndex])
          expect(CitiesIndex.all.to_a.length).to eq 2
          expect(CountriesIndex.all.to_a.length).to eq 2
        end
      end
    end

    context 'retries' do
      let(:time) { Time.now.to_i }
      before do
        Timecop.freeze
        Chewy.strategy(:urgent)
        City.create!(id: 1)
      end

      after do
        Chewy.strategy.pop
        Timecop.return
      end

      specify 'journal was cleaned after the first call' do
        expect(Chewy::Stash::Journal)
          .to receive(:entries).exactly(2).and_call_original
        Chewy::Journal::Apply.since(time)
      end

      context 'endless journal' do
        let(:count_of_checks) { 10 } # default
        let!(:journal_entries) do
          record = Chewy::Stash::Journal.entries(time).first
          Array.new(count_of_checks) do |i|
            Chewy::Stash::Journal.new(
              record.attributes.merge(
                'created_at' => time.to_i + i,
                'references' => [i.to_s]
              )
            )
          end
        end

        specify '10 retries by default' do
          expect(Chewy::Stash::Journal)
            .to receive(:entries).exactly(count_of_checks) { [journal_entries.shift].compact }
          Chewy::Journal::Apply.since(time)
        end

        specify 'with :once parameter set' do
          expect(Chewy::Stash::Journal)
            .to receive(:entries).exactly(1) { [journal_entries.shift].compact }
          Chewy::Journal::Apply.since(time, once: true)
        end

        context 'with retries parameter set' do
          let(:retries) { 5 }

          specify do
            expect(Chewy::Stash::Journal)
              .to receive(:entries).exactly(retries) { [journal_entries.shift].compact }
            Chewy::Journal::Apply.since(time, retries: retries)
          end
        end
      end
    end
  end

  describe '.group' do
    let(:derivable_type_name) { 'type' }
    let(:another_derivable_type_name) { 'type' }
    let(:entry) { Chewy::Stash::Journal.new('references' => ['1']) }
    let(:another_entry) { Chewy::Stash::Journal.new('references' => ['2']) }
    before do
      allow(entry)
        .to receive(:derivable_type_name).and_return(derivable_type_name)
      allow(another_entry)
        .to receive(:derivable_type_name).and_return(another_derivable_type_name)
    end
    subject { described_class.group([entry, another_entry]) }

    specify do
      expect(subject.size).to eq(1)
      expect(subject.first.references).to eq([1, 2])
    end

    context do
      let(:another_derivable_type_name) { 'whatever' }

      specify do
        expect(subject.size).to eq(2)
        expect(subject.first.references).to eq(entry.references)
        expect(subject.last.references).to eq(another_entry.references)
      end
    end
  end

  describe '.recent_timestamp' do
    let(:time) { Time.now.to_i }
    let(:entry) { Chewy::Stash::Journal.new('created_at' => time) }
    let(:another_entry) { Chewy::Stash::Journal.new('created_at' => time + 1) }
    subject { described_class.recent_timestamp([entry, another_entry]) }

    it { is_expected.to eq(time + 1) }
  end

  describe '.subtract' do
    let(:full_type_name) { 'type' }
    let(:another_full_type_name) { 'type' }
    let(:entry) { Chewy::Stash::Journal.new('references' => ['1']) }
    let(:another_entry) { Chewy::Stash::Journal.new('references' => ['2']) }
    before do
      allow(entry)
        .to receive(:full_type_name).and_return(full_type_name)
      allow(another_entry)
        .to receive(:full_type_name).and_return(another_full_type_name)
    end
    let(:from) { [entry] }
    let(:what) { [another_entry] }
    subject { described_class.subtract(from, what) }

    specify { expect(subject.size).to eq(1) }
    specify { expect(subject.first.references).to eq([1]) }

    context 'references have same elements' do
      let(:another_entry) { Chewy::Stash::Journal.new('references' => %w[1 2]) }

      specify { expect(subject.size).to eq(0) }

      context 'not all elements are covered by subtracting array' do
        let(:entry) { Chewy::Stash::Journal.new('references' => %w[1 3]) }

        specify { expect(subject.size).to eq(1) }
        specify { expect(subject.first.references).to eq([3]) }
      end
    end
  end
end

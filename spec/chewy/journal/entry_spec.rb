require 'spec_helper'

describe Chewy::Journal::Entry do
  before do
    stub_model(:city) do
      update_index 'city', :self
    end
    stub_index('city') do
      define_type City do
        default_import_options journal: true
      end
    end
  end

  describe '.since' do
    let(:time) { Time.now.to_i }
    before do
      Timecop.freeze(time)
      Chewy.massacre
      Chewy.strategy(:urgent) { City.create!(id: 1) }
    end
    subject { described_class.since(time) }

    its(:length) { is_expected.to eq(1) }

    context 'with indices parameter provided' do
      subject { described_class.since(time, indices) }

      context 'it ignores empty array' do
        let(:indices) { [] }
        its(:length) { is_expected.to eq(1) }
      end

      context do
        let(:indices) { [CityIndex::City2] }
        before do
          stub_index('city') do
            define_type :city2 do
              default_import_options journal: true
            end
          end
        end

        its(:length) { is_expected.to eq(1) }
      end
    end
  end

  describe '.group' do
    let(:full_type_name) { 'type' }
    let(:another_full_type_name) { 'type' }
    let(:entry) { described_class.new('object_ids' => [1]) }
    let(:another_entry) { described_class.new('object_ids' => [2]) }
    before do
      allow(entry)
        .to receive(:full_type_name).and_return(full_type_name)
      allow(another_entry)
        .to receive(:full_type_name).and_return(another_full_type_name)
    end
    subject { described_class.group([entry, another_entry]) }

    specify do
      expect(subject.length).to eq(1)
      expect(subject.first.object_ids).to eq([1, 2])
    end

    context do
      let(:another_full_type_name) { 'whatever' }

      specify do
        expect(subject.length).to eq(2)
        expect(subject.first.object_ids).to eq(entry.object_ids)
        expect(subject.last.object_ids).to eq(another_entry.object_ids)
      end
    end
  end

  describe '.recent_timestamp' do
    let(:time) { Time.now.to_i }
    let(:entry) { described_class.new('created_at' => time) }
    let(:another_entry) { described_class.new('created_at' => time + 1) }
    subject { described_class.recent_timestamp([entry, another_entry]) }

    it { is_expected.to eq(time + 1) }
  end

  describe '.subtract' do
    let(:full_type_name) { 'type' }
    let(:another_full_type_name) { 'type' }
    let(:entry) { described_class.new('object_ids' => [1]) }
    let(:another_entry) { described_class.new('object_ids' => [2]) }
    before do
      allow(entry)
        .to receive(:full_type_name).and_return(full_type_name)
      allow(another_entry)
        .to receive(:full_type_name).and_return(another_full_type_name)
    end
    let(:from) { [entry] }
    let(:what) { [another_entry] }
    subject { described_class.subtract(from, what) }

    specify { expect { subject }.not_to change { from.length } }
    specify { expect(entry.object_ids).to eq([1]) }

    context 'object_ids have same elements' do
      let(:another_entry) { described_class.new('object_ids' => [1, 2]) }

      specify { expect { subject }.to change { from.length }.from(1).to(0) }
      specify do
        subject
        expect(entry.object_ids).to eq([])
      end

      context 'not all elements are covered by subtracting array' do
        let(:entry) { described_class.new('object_ids' => [1, 3]) }

        specify { expect { subject }.not_to change { from.length } }
        specify do
          subject
          expect(entry.object_ids).to eq([3])
        end
      end
    end
  end

  describe '#merge' do
    let(:time) { Time.now.to_i }
    let(:index_name) { 'index' }
    let(:type_name) { 'type' }
    let(:object_ids) { [1] }
    let(:entry) do
      described_class.new('index_name' => index_name,
                          'type_name' => type_name,
                          'object_ids' => object_ids,
                          'created_at' => time)
    end
    let(:another_index_name) { 'index' }
    let(:another_type_name) { 'type' }
    let(:another_object_ids) { [2] }
    let(:another_time) { time + 1 }
    let(:another_entry) do
      described_class.new('index_name' => another_index_name,
                          'type_name' => another_type_name,
                          'object_ids' => another_object_ids,
                          'created_at' => another_time)
    end
    subject { entry.merge(another_entry) }

    specify do
      expect(subject).to eq(entry)
      expect(entry.created_at).to eq(another_entry.created_at)
      expect(entry.object_ids).to eq([1, 2])
    end

    shared_examples_for 'merge does not change the entry' do
      it { is_expected.to eq(entry) }
      specify { expect { subject }.not_to change(entry, :created_at) }
      specify { expect { subject }.not_to change(entry, :object_ids) }
    end

    context 'different types' do
      let(:another_type_name) { 'whatever' }
      include_examples 'merge does not change the entry'
    end

    context 'merge with nil' do
      let(:another_entry) { nil }
      include_examples 'merge does not change the entry'
    end

    context 'original entry has more recent time' do
      let(:another_time) { time - 1 }
      specify { expect { subject }.not_to change(entry, :created_at) }
    end
  end

  describe '#empty?' do
    let(:object_ids) { [] }
    subject { described_class.new('object_ids' => object_ids).empty? }

    it { is_expected.to eq(true) }

    context do
      let(:object_ids) { nil }
      it { is_expected.to eq(true) }
    end

    context do
      let(:object_ids) { [1] }
      it { is_expected.to eq(false) }
    end
  end

  describe '#full_type_name' do
    subject do
      described_class.new('index_name' => 'index', 'type_name' => 'type')
        .full_type_name
    end
    it { is_expected.to eq('index#type') }
  end

  describe '#index' do
    let(:index_name) { 'wrong_index_name' }
    let(:type_name) { 'city' }
    subject do
      described_class
        .new('index_name' => index_name, 'type_name' => type_name).index
    end

    specify { expect { subject }.to raise_error(Chewy::UnderivableType) }

    context do
      let(:index_name) { 'city' }
      it { is_expected.to eq(CityIndex::City) }
    end
  end

  describe '#==' do
    let(:full_type_name) { 'type' }
    let(:another_full_type_name) { 'type' }
    let(:entry) { described_class.new }
    let(:another_entry) { described_class.new }
    before do
      expect(entry).to receive(:full_type_name).and_return(full_type_name)
      expect(another_entry)
        .to receive(:full_type_name).and_return(another_full_type_name)
    end
    subject { entry == another_entry }

    it { is_expected.to eq(true) }

    context do
      let(:another_full_type_name) { 'whatever' }
      it { is_expected.to eq(false) }
    end
  end
end

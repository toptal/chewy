require 'spec_helper'

describe Chewy::Stash::Journal, :orm do
  def fetch_deleted_number(response)
    response['deleted'] || response['_indices']['_all']['deleted']
  end

  before { Chewy.massacre }

  before do
    stub_model(:city)
    stub_index(:places) do
      define_type City
      define_type :country
    end
    stub_index(:users) { define_type :user }
  end

  before { Timecop.freeze }
  after { Timecop.return }

  before do
    PlacesIndex::City.import!(City.new(id: 1, name: 'City'), journal: true)
    Timecop.travel(Time.now + 1.minute) do
      PlacesIndex::Country.import!([id: 2, name: 'Country'], journal: true)
    end
    Timecop.travel(Time.now + 2.minutes) do
      UsersIndex::User.import!([id: 3, name: 'User'], journal: true)
    end
  end

  describe '.clean' do
    specify { expect(fetch_deleted_number(described_class.clean)).to eq(3) }
    specify { expect(fetch_deleted_number(described_class.clean(Time.now - 30.seconds))).to eq(0) }
    specify { expect(fetch_deleted_number(described_class.clean(Time.now + 30.seconds))).to eq(1) }
    specify { expect(fetch_deleted_number(described_class.clean(Time.now + 90.seconds))).to eq(2) }
    specify { expect(fetch_deleted_number(described_class.clean(only: UsersIndex))).to eq(1) }
    specify { expect(fetch_deleted_number(described_class.clean(only: [PlacesIndex::City, UsersIndex]))).to eq(2) }

    specify { expect(fetch_deleted_number(described_class.clean(Time.now + 30.seconds, only: PlacesIndex::Country))).to eq(0) }
    specify { expect(fetch_deleted_number(described_class.clean(Time.now + 30.seconds, only: PlacesIndex::City))).to eq(1) }
  end

  describe '.entries' do
    specify do
      expect(described_class.entries(Time.now - 30.seconds).map(&:references))
        .to contain_exactly([1], [{'id' => 2, 'name' => 'Country'}], [{'id' => 3, 'name' => 'User'}])
    end
    specify do
      expect(described_class.entries(Time.now + 30.seconds).map(&:references))
        .to contain_exactly([{'id' => 2, 'name' => 'Country'}], [{'id' => 3, 'name' => 'User'}])
    end
    specify do
      expect(described_class.entries(Time.now + 90.seconds).map(&:references))
        .to contain_exactly([{'id' => 3, 'name' => 'User'}])
    end

    specify do
      expect(described_class.entries(Time.now - 30.seconds, only: UsersIndex).map(&:references))
        .to contain_exactly([{'id' => 3, 'name' => 'User'}])
    end
    specify do
      expect(described_class.entries(Time.now - 30.seconds, only: [PlacesIndex::City, UsersIndex]).map(&:references))
        .to contain_exactly([1], [{'id' => 3, 'name' => 'User'}])
    end
    specify do
      expect(described_class.entries(Time.now + 30.seconds, only: [PlacesIndex::City, UsersIndex]).map(&:references))
        .to contain_exactly([{'id' => 3, 'name' => 'User'}])
    end
  end

  describe '.for' do
    specify { expect(described_class.for(UsersIndex).map(&:index_name)).to eq(['users']) }
    specify { expect(described_class.for(PlacesIndex).map(&:type_name)).to contain_exactly('city', 'country') }
    specify { expect(described_class.for(PlacesIndex::City, UsersIndex).map(&:index_name)).to contain_exactly('places', 'users') }
  end

  describe '#derivable_type_name' do
    specify { expect(described_class.new(index_name: 'index', type_name: 'type').derivable_type_name).to eq('index#type') }
  end

  describe '#type' do
    let(:index_name) { 'users' }
    let(:type_name) { 'city' }
    subject { described_class.new('index_name' => index_name, 'type_name' => type_name).type }

    specify { expect { subject }.to raise_error(Chewy::UnderivableType) }

    context do
      let(:index_name) { 'places' }
      it { is_expected.to eq(PlacesIndex::City) }
    end
  end

  describe '#merge' do
    let(:time) { Time.now }
    let(:index_name) { 'index' }
    let(:type_name) { 'type' }
    let(:references) { [1] }
    let(:entry) do
      described_class.new(
        index_name: index_name,
        type_name: type_name,
        references: references.map(&:to_json),
        created_at: time
      )
    end
    let(:another_index_name) { 'index' }
    let(:another_type_name) { 'type' }
    let(:another_references) { [2] }
    let(:another_time) { time + 1 }
    let(:another_entry) do
      described_class.new(
        index_name: another_index_name,
        type_name: another_type_name,
        references: another_references.map(&:to_json),
        created_at: another_time
      )
    end
    subject { entry.merge(another_entry) }

    specify do
      expect(subject.created_at).to eq(another_time)
      expect(subject.references).to eq([1, 2])
    end

    context 'different types' do
      let(:another_type_name) { 'whatever' }
      specify { expect { subject }.not_to change(entry, :created_at) }
      specify { expect { subject }.not_to change(entry, :references) }
      specify { expect { subject }.not_to change(another_entry, :created_at) }
      specify { expect { subject }.not_to change(another_entry, :references) }
    end

    context 'merge with nil' do
      let(:another_entry) { nil }
      specify { expect { subject }.not_to change(entry, :created_at) }
      specify { expect { subject }.not_to change(entry, :references) }
    end

    context 'original entry has more recent time' do
      let(:another_time) { time - 1 }
      specify { expect { subject }.not_to change(entry, :created_at) }
      specify { expect { subject }.not_to change(another_entry, :created_at) }
    end
  end
end

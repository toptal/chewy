require 'spec_helper'

describe Chewy::Stash::Journal, :orm do
  def fetch_deleted_number(response)
    response['deleted'] || response['_indices']['_all']['deleted']
  end

  before { Chewy.massacre }

  before do
    stub_model(:city)
    stub_index(:cities) do
      index_scope City
    end
    stub_index(:countries)
    stub_index(:users)
    stub_index(:borogoves)
  end

  before { Timecop.freeze }
  after { Timecop.return }

  before do
    CitiesIndex.import!(City.new(id: 1, name: 'City'), journal: true)
    Timecop.travel(Time.now + 1.minute) do
      CountriesIndex.import!([id: 2, name: 'Country'], journal: true)
    end
    Timecop.travel(Time.now + 2.minutes) do
      UsersIndex.import!([id: 3, name: 'User'], journal: true)
    end
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
      expect(described_class.entries(Time.now - 30.seconds, only: [CitiesIndex, UsersIndex]).map(&:references))
        .to contain_exactly([1], [{'id' => 3, 'name' => 'User'}])
    end
    specify do
      expect(described_class.entries(Time.now + 30.seconds, only: [CitiesIndex, UsersIndex]).map(&:references))
        .to contain_exactly([{'id' => 3, 'name' => 'User'}])
    end
    specify do
      expect(described_class.entries(Time.now + 30.seconds, only: [BorogovesIndex])).to eq([])
    end
  end

  describe '.clean' do
    specify { expect(fetch_deleted_number(described_class.clean)).to eq(3) }
    specify { expect(fetch_deleted_number(described_class.clean(Time.now - 30.seconds))).to eq(0) }
    specify { expect(fetch_deleted_number(described_class.clean(Time.now + 30.seconds))).to eq(1) }
    specify { expect(fetch_deleted_number(described_class.clean(Time.now + 90.seconds))).to eq(2) }
    specify { expect(fetch_deleted_number(described_class.clean(only: BorogovesIndex))).to eq(0) }
    specify { expect(fetch_deleted_number(described_class.clean(only: UsersIndex))).to eq(1) }
    specify { expect(fetch_deleted_number(described_class.clean(only: [CitiesIndex, UsersIndex]))).to eq(2) }

    specify do
      expect(fetch_deleted_number(described_class.clean(Time.now + 30.seconds, only: CountriesIndex))).to eq(0)
    end
    specify { expect(fetch_deleted_number(described_class.clean(Time.now + 30.seconds, only: CitiesIndex))).to eq(1) }
  end

  describe '.for' do
    specify { expect(described_class.for(UsersIndex).map(&:index_name)).to eq(['users']) }
    specify do
      expect(described_class.for(CitiesIndex, UsersIndex).map(&:index_name)).to contain_exactly('cities', 'users')
    end
  end
end

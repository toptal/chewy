require 'spec_helper'

describe Chewy::Index::Actions do
  before { Chewy.massacre }

  before { stub_index :dummies }

  describe '.exists?' do
    specify { expect(DummiesIndex.exists?).to eq(false) }

    context do
      before { DummiesIndex.create }
      specify { expect(DummiesIndex.exists?).to eq(true) }
    end
  end

  describe '.create' do
    specify { expect(DummiesIndex.create['acknowledged']).to eq(true) }
    specify { expect(DummiesIndex.create('2013')['acknowledged']).to eq(true) }

    context do
      before { DummiesIndex.create }
      specify { expect(DummiesIndex.create).to eq(false) }
      specify { expect(DummiesIndex.create('2013')).to eq(false) }
    end

    context do
      before { DummiesIndex.create '2013' }
      specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(true) }
      specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(true) }
      specify { expect(DummiesIndex.aliases).to eq([]) }
      specify { expect(DummiesIndex.indexes).to eq(['dummies_2013']) }
      specify { expect(DummiesIndex.create('2013')).to eq(false) }
      specify { expect(DummiesIndex.create('2014')['acknowledged']).to eq(true) }

      context do
        before { DummiesIndex.create '2014' }
        specify { expect(DummiesIndex.indexes).to match_array(['dummies_2013', 'dummies_2014']) }
      end
    end

    context do
      before { DummiesIndex.create '2013', alias: false }
      specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(false) }
      specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(true) }
      specify { expect(DummiesIndex.aliases).to eq([]) }
      specify { expect(DummiesIndex.indexes).to eq([]) }
    end
  end

  describe '.create!' do
    specify { expect(DummiesIndex.create!['acknowledged']).to eq(true) }
    specify { expect(DummiesIndex.create!('2013')['acknowledged']).to eq(true) }

    context do
      before { DummiesIndex.create }
      specify do
        skip_on_version_gte('2.0', 'format of exception changed in 2.x')
        expect { DummiesIndex.create! }.to raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest).with_message(/\[\[dummies\] already exists\]/)
      end
      specify do
        skip_on_version_lt('2.0', 'format of exception was changed')
        expect { DummiesIndex.create! }.to raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest).with_message(/index_already_exists_exception.*dummies/)
      end
      specify { expect { DummiesIndex.create!('2013') }.to raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest).with_message(/Invalid alias name \[dummies\]/) }
    end

    context do
      before { DummiesIndex.create! '2013' }
      specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(true) }
      specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(true) }
      specify { expect(DummiesIndex.aliases).to eq([]) }
      specify { expect(DummiesIndex.indexes).to eq(['dummies_2013']) }
      specify do
        skip_on_version_gte('2.0', 'format of exception changed in 2.x')
        expect { DummiesIndex.create!('2013') }.to raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest).with_message(/\[\[dummies_2013\] already exists\]/)
      end
      specify do
        skip_on_version_lt('2.0', 'format of exception was changed')
        expect { DummiesIndex.create!('2013') }.to raise_error(Elasticsearch::Transport::Transport::Errors::BadRequest).with_message(/index_already_exists_exception.*dummies_2013/)
      end
      specify { expect(DummiesIndex.create!('2014')['acknowledged']).to eq(true) }

      context do
        before { DummiesIndex.create! '2014' }
        specify { expect(DummiesIndex.indexes).to match_array(['dummies_2013', 'dummies_2014']) }
      end
    end

    context do
      before { DummiesIndex.create! '2013', alias: false }
      specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(false) }
      specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(true) }
      specify { expect(DummiesIndex.aliases).to eq([]) }
      specify { expect(DummiesIndex.indexes).to eq([]) }
    end
  end

  describe '.delete' do
    specify { expect(DummiesIndex.delete).to eq(false) }
    specify { expect(DummiesIndex.delete('dummies_2013')).to eq(false) }

    context do
      before { DummiesIndex.create }
      specify { expect(DummiesIndex.delete['acknowledged']).to eq(true) }

      context do
        before { DummiesIndex.delete }
        specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(false) }
      end
    end

    context do
      before { DummiesIndex.create '2013' }
      specify { expect(DummiesIndex.delete('2013')['acknowledged']).to eq(true) }

      context do
        before { DummiesIndex.delete('2013') }
        specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(false) }
        specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(false) }
      end

      context do
        before { DummiesIndex.create '2014' }
        specify { expect(DummiesIndex.delete['acknowledged']).to eq(true) }

        context do
          before { DummiesIndex.delete }
          specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(false) }
          specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(false) }
          specify { expect(Chewy.client.indices.exists(index: 'dummies_2014')).to eq(false) }
        end

        context do
          before { DummiesIndex.delete('2014') }
          specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(true) }
          specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(true) }
          specify { expect(Chewy.client.indices.exists(index: 'dummies_2014')).to eq(false) }
        end
      end
    end
  end

  describe '.delete!' do
    specify { expect { DummiesIndex.delete! }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound) }
    specify { expect { DummiesIndex.delete!('2013') }.to raise_error(Elasticsearch::Transport::Transport::Errors::NotFound) }

    context do
      before { DummiesIndex.create }
      specify { expect(DummiesIndex.delete!['acknowledged']).to eq(true) }

      context do
        before { DummiesIndex.delete! }
        specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(false) }
      end
    end

    context do
      before { DummiesIndex.create '2013' }
      specify { expect(DummiesIndex.delete!('2013')['acknowledged']).to eq(true) }

      context do
        before { DummiesIndex.delete!('2013') }
        specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(false) }
        specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(false) }
      end

      context do
        before { DummiesIndex.create '2014' }
        specify { expect(DummiesIndex.delete!['acknowledged']).to eq(true) }

        context do
          before { DummiesIndex.delete! }
          specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(false) }
          specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(false) }
          specify { expect(Chewy.client.indices.exists(index: 'dummies_2014')).to eq(false) }
        end

        context do
          before { DummiesIndex.delete!('2014') }
          specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(true) }
          specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(true) }
          specify { expect(Chewy.client.indices.exists(index: 'dummies_2014')).to eq(false) }
        end
      end
    end
  end

  describe '.purge' do
    specify { expect(DummiesIndex.purge['acknowledged']).to eq(true) }
    specify { expect(DummiesIndex.purge('2013')['acknowledged']).to eq(true) }

    context do
      before { DummiesIndex.purge }
      specify { expect(DummiesIndex).to be_exists }
      specify { expect(DummiesIndex.aliases).to eq([]) }
      specify { expect(DummiesIndex.indexes).to eq([]) }

      context do
        before { DummiesIndex.purge }
        specify { expect(DummiesIndex).to be_exists }
        specify { expect(DummiesIndex.aliases).to eq([]) }
        specify { expect(DummiesIndex.indexes).to eq([]) }
      end

      context do
        before { DummiesIndex.purge('2013') }
        specify { expect(DummiesIndex).to be_exists }
        specify { expect(DummiesIndex.aliases).to eq([]) }
        specify { expect(DummiesIndex.indexes).to eq(['dummies_2013']) }
      end
    end

    context do
      before { DummiesIndex.purge('2013') }
      specify { expect(DummiesIndex).to be_exists }
      specify { expect(DummiesIndex.aliases).to eq([]) }
      specify { expect(DummiesIndex.indexes).to eq(['dummies_2013']) }

      context do
        before { DummiesIndex.purge }
        specify { expect(DummiesIndex).to be_exists }
        specify { expect(DummiesIndex.aliases).to eq([]) }
        specify { expect(DummiesIndex.indexes).to eq([]) }
      end

      context do
        before { DummiesIndex.purge('2014') }
        specify { expect(DummiesIndex).to be_exists }
        specify { expect(DummiesIndex.aliases).to eq([]) }
        specify { expect(DummiesIndex.indexes).to eq(['dummies_2014']) }
      end
    end
  end

  describe '.purge!' do
    specify { expect(DummiesIndex.purge!['acknowledged']).to eq(true) }
    specify { expect(DummiesIndex.purge!('2013')['acknowledged']).to eq(true) }

    context do
      before { DummiesIndex.purge! }
      specify { expect(DummiesIndex).to be_exists }
      specify { expect(DummiesIndex.aliases).to eq([]) }
      specify { expect(DummiesIndex.indexes).to eq([]) }

      context do
        before { DummiesIndex.purge! }
        specify { expect(DummiesIndex).to be_exists }
        specify { expect(DummiesIndex.aliases).to eq([]) }
        specify { expect(DummiesIndex.indexes).to eq([]) }
      end

      context do
        before { DummiesIndex.purge!('2013') }
        specify { expect(DummiesIndex).to be_exists }
        specify { expect(DummiesIndex.aliases).to eq([]) }
        specify { expect(DummiesIndex.indexes).to eq(['dummies_2013']) }
      end
    end

    context do
      before { DummiesIndex.purge!('2013') }
      specify { expect(DummiesIndex).to be_exists }
      specify { expect(DummiesIndex.aliases).to eq([]) }
      specify { expect(DummiesIndex.indexes).to eq(['dummies_2013']) }

      context do
        before { DummiesIndex.purge! }
        specify { expect(DummiesIndex).to be_exists }
        specify { expect(DummiesIndex.aliases).to eq([]) }
        specify { expect(DummiesIndex.indexes).to eq([]) }
      end

      context do
        before { DummiesIndex.purge!('2014') }
        specify { expect(DummiesIndex).to be_exists }
        specify { expect(DummiesIndex.aliases).to eq([]) }
        specify { expect(DummiesIndex.indexes).to eq(['dummies_2014']) }
      end
    end
  end

  describe '.import', :orm do
    before do
      stub_model(:city)
      stub_index(:cities) do
        define_type City
      end
    end
    let!(:dummy_cities) { 3.times.map { |i| City.create(id: i + 1, name: "name#{i}") } }

    specify { expect(CitiesIndex.import).to eq(true) }

    context do
      before do
        stub_index(:cities) do
          define_type City do
            field :name, type: 'object'
          end
        end
      end

      specify { expect(CitiesIndex.import(city: dummy_cities)).to eq(false) }
    end
  end

  describe '.import!', :orm do
    before do
      stub_model(:city)
      stub_index(:cities) do
        define_type City
      end
    end
    let!(:dummy_cities) { 3.times.map { |i| City.create(id: i + 1, name: "name#{i}") } }

    specify { expect(CitiesIndex.import!).to eq(true) }

    context do
      before do
        stub_index(:cities) do
          define_type City do
            field :name, type: 'object'
          end
        end
      end

      specify { expect { CitiesIndex.import!(city: dummy_cities) }.to raise_error Chewy::ImportFailed }
    end
  end

  describe '.reset!', :orm do
    before do
      stub_model(:city)
      stub_index(:cities) do
        define_type City
      end
    end

    before { City.create!(id: 1, name: 'Moscow') }

    specify { expect(CitiesIndex.reset!).to eq(true) }
    specify { expect(CitiesIndex.reset!('2013')).to eq(true) }

    context do
      before { CitiesIndex.reset! }

      specify { expect(CitiesIndex.all).to have(1).item }
      specify { expect(CitiesIndex.aliases).to eq([]) }
      specify { expect(CitiesIndex.indexes).to eq([]) }

      context do
        before { CitiesIndex.reset!('2013') }

        specify { expect(CitiesIndex.all).to have(1).item }
        specify { expect(CitiesIndex.aliases).to eq([]) }
        specify { expect(CitiesIndex.indexes).to eq(['cities_2013']) }
      end

      context do
        before { CitiesIndex.reset! }

        specify { expect(CitiesIndex.all).to have(1).item }
        specify { expect(CitiesIndex.aliases).to eq([]) }
        specify { expect(CitiesIndex.indexes).to eq([]) }
      end
    end

    context do
      before { CitiesIndex.reset!('2013') }

      specify { expect(CitiesIndex.all).to have(1).item }
      specify { expect(CitiesIndex.aliases).to eq([]) }
      specify { expect(CitiesIndex.indexes).to eq(['cities_2013']) }

      context do
        before { CitiesIndex.reset!('2014') }

        specify { expect(CitiesIndex.all).to have(1).item }
        specify { expect(CitiesIndex.aliases).to eq([]) }
        specify { expect(CitiesIndex.indexes).to eq(['cities_2014']) }
        specify { expect(Chewy.client.indices.exists(index: 'cities_2013')).to eq(false) }
      end

      context do
        before { CitiesIndex.reset! }

        specify { expect(CitiesIndex.all).to have(1).item }
        specify { expect(CitiesIndex.aliases).to eq([]) }
        specify { expect(CitiesIndex.indexes).to eq([]) }
        specify { expect(Chewy.client.indices.exists(index: 'cities_2013')).to eq(false) }
      end
    end
  end
end

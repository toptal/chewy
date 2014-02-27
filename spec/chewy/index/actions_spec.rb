require 'spec_helper'

describe Chewy::Index::Actions do
  include ClassHelpers
  before { Chewy::Index.client.indices.delete }

  before { stub_index :dummies }

  describe '.exists?' do
    specify { DummiesIndex.exists?.should be_false }

    context do
      before { DummiesIndex.create }
      specify { DummiesIndex.exists?.should be_true }
    end
  end

  describe '.create' do
    specify { DummiesIndex.create.should be_true }
    specify { DummiesIndex.create('2013').should be_true }

    context do
      before { DummiesIndex.create }
      specify { DummiesIndex.create.should be_false }
      specify { DummiesIndex.create('2013').should be_false }
    end

    context do
      before { DummiesIndex.create '2013' }
      specify { Chewy.client.indices.exists(index: 'dummies').should be_true }
      specify { Chewy.client.indices.exists(index: 'dummies_2013').should be_true }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == ['dummies_2013'] }
      specify { DummiesIndex.create('2013').should be_false }
      specify { DummiesIndex.create('2014').should be_true }

      context do
        before { DummiesIndex.create '2014' }
        specify { DummiesIndex.indexes.should =~ ['dummies_2013', 'dummies_2014'] }
      end
    end

    context do
      before { DummiesIndex.create '2013', alias: false }
      specify { Chewy.client.indices.exists(index: 'dummies').should be_false }
      specify { Chewy.client.indices.exists(index: 'dummies_2013').should be_true }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == [] }
    end
  end

  describe '.create!' do
    specify { DummiesIndex.create!.should be_true }
    specify { DummiesIndex.create!('2013').should be_true }

    context do
      before { DummiesIndex.create }
      specify { expect { DummiesIndex.create! }.to raise_error }
      specify { expect { DummiesIndex.create!('2013') }.to raise_error }
    end

    context do
      before { DummiesIndex.create! '2013' }
      specify { Chewy.client.indices.exists(index: 'dummies').should be_true }
      specify { Chewy.client.indices.exists(index: 'dummies_2013').should be_true }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == ['dummies_2013'] }
      specify { expect { DummiesIndex.create!('2013') }.to raise_error }
      specify { DummiesIndex.create!('2014').should be_true }

      context do
        before { DummiesIndex.create! '2014' }
        specify { DummiesIndex.indexes.should =~ ['dummies_2013', 'dummies_2014'] }
      end
    end

    context do
      before { DummiesIndex.create! '2013', alias: false }
      specify { Chewy.client.indices.exists(index: 'dummies').should be_false }
      specify { Chewy.client.indices.exists(index: 'dummies_2013').should be_true }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == [] }
    end
  end

  describe '.delete' do
    specify { DummiesIndex.delete.should be_false }
    specify { DummiesIndex.delete('dummies_2013').should be_false }

    context do
      before { DummiesIndex.create }
      specify { DummiesIndex.delete.should be_true }

      context do
        before { DummiesIndex.delete }
        specify { Chewy.client.indices.exists(index: 'dummies').should be_false }
      end
    end

    context do
      before { DummiesIndex.create '2013' }
      specify { DummiesIndex.delete('2013').should be_true }

      context do
        before { DummiesIndex.delete('2013') }
        specify { Chewy.client.indices.exists(index: 'dummies').should be_false }
        specify { Chewy.client.indices.exists(index: 'dummies_2013').should be_false }
      end

      context do
        before { DummiesIndex.create '2014' }
        specify { DummiesIndex.delete.should be_true }

        context do
          before { DummiesIndex.delete }
          specify { Chewy.client.indices.exists(index: 'dummies').should be_false }
          specify { Chewy.client.indices.exists(index: 'dummies_2013').should be_false }
          specify { Chewy.client.indices.exists(index: 'dummies_2014').should be_false }
        end

        context do
          before { DummiesIndex.delete('2014') }
          specify { Chewy.client.indices.exists(index: 'dummies').should be_true }
          specify { Chewy.client.indices.exists(index: 'dummies_2013').should be_true }
          specify { Chewy.client.indices.exists(index: 'dummies_2014').should be_false }
        end
      end
    end
  end

  describe '.delete!' do
    specify { expect { DummiesIndex.delete! }.to raise_error }
    specify { expect { DummiesIndex.delete!('2013') }.to raise_error }

    context do
      before { DummiesIndex.create }
      specify { DummiesIndex.delete!.should be_true }

      context do
        before { DummiesIndex.delete! }
        specify { Chewy.client.indices.exists(index: 'dummies').should be_false }
      end
    end

    context do
      before { DummiesIndex.create '2013' }
      specify { DummiesIndex.delete!('2013').should be_true }

      context do
        before { DummiesIndex.delete!('2013') }
        specify { Chewy.client.indices.exists(index: 'dummies').should be_false }
        specify { Chewy.client.indices.exists(index: 'dummies_2013').should be_false }
      end

      context do
        before { DummiesIndex.create '2014' }
        specify { DummiesIndex.delete!.should be_true }

        context do
          before { DummiesIndex.delete! }
          specify { Chewy.client.indices.exists(index: 'dummies').should be_false }
          specify { Chewy.client.indices.exists(index: 'dummies_2013').should be_false }
          specify { Chewy.client.indices.exists(index: 'dummies_2014').should be_false }
        end

        context do
          before { DummiesIndex.delete!('2014') }
          specify { Chewy.client.indices.exists(index: 'dummies').should be_true }
          specify { Chewy.client.indices.exists(index: 'dummies_2013').should be_true }
          specify { Chewy.client.indices.exists(index: 'dummies_2014').should be_false }
        end
      end
    end
  end

  describe '.purge' do
    specify { DummiesIndex.purge.should be_true }
    specify { DummiesIndex.purge('2013').should be_true }

    context do
      before { DummiesIndex.purge }
      specify { DummiesIndex.should be_exists }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == [] }

      context do
        before { DummiesIndex.purge }
        specify { DummiesIndex.should be_exists }
        specify { DummiesIndex.aliases.should == [] }
        specify { DummiesIndex.indexes.should == [] }
      end

      context do
        before { DummiesIndex.purge('2013') }
        specify { DummiesIndex.should be_exists }
        specify { DummiesIndex.aliases.should == [] }
        specify { DummiesIndex.indexes.should == ['dummies_2013'] }
      end
    end

    context do
      before { DummiesIndex.purge('2013') }
      specify { DummiesIndex.should be_exists }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == ['dummies_2013'] }

      context do
        before { DummiesIndex.purge }
        specify { DummiesIndex.should be_exists }
        specify { DummiesIndex.aliases.should == [] }
        specify { DummiesIndex.indexes.should == [] }
      end

      context do
        before { DummiesIndex.purge('2014') }
        specify { DummiesIndex.should be_exists }
        specify { DummiesIndex.aliases.should == [] }
        specify { DummiesIndex.indexes.should == ['dummies_2014'] }
      end
    end
  end

  describe '.purge!' do
    specify { DummiesIndex.purge!.should be_true }
    specify { DummiesIndex.purge!('2013').should be_true }

    context do
      before { DummiesIndex.purge! }
      specify { DummiesIndex.should be_exists }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == [] }

      context do
        before { DummiesIndex.purge! }
        specify { DummiesIndex.should be_exists }
        specify { DummiesIndex.aliases.should == [] }
        specify { DummiesIndex.indexes.should == [] }
      end

      context do
        before { DummiesIndex.purge!('2013') }
        specify { DummiesIndex.should be_exists }
        specify { DummiesIndex.aliases.should == [] }
        specify { DummiesIndex.indexes.should == ['dummies_2013'] }
      end
    end

    context do
      before { DummiesIndex.purge!('2013') }
      specify { DummiesIndex.should be_exists }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == ['dummies_2013'] }

      context do
        before { DummiesIndex.purge! }
        specify { DummiesIndex.should be_exists }
        specify { DummiesIndex.aliases.should == [] }
        specify { DummiesIndex.indexes.should == [] }
      end

      context do
        before { DummiesIndex.purge!('2014') }
        specify { DummiesIndex.should be_exists }
        specify { DummiesIndex.aliases.should == [] }
        specify { DummiesIndex.indexes.should == ['dummies_2014'] }
      end
    end
  end

  describe '.import' do
    before do
      stub_model(:city)
      stub_index(:cities) do
        define_type City
      end
    end
    let!(:dummy_cities) { 3.times.map { |i| City.create(name: "name#{i}") } }

    specify { CitiesIndex.import.should == true }

    context do
      before do
        stub_index(:cities) do
          define_type City do
            field :name, type: 'object'
          end
        end.tap(&:create!)
      end

      specify { CitiesIndex.import(city: dummy_cities).should == false }
    end
  end

  describe '.import!' do
    before do
      stub_model(:city)
      stub_index(:cities) do
        define_type City
      end
    end
    let!(:dummy_cities) { 3.times.map { |i| City.create(name: "name#{i}") } }

    specify { CitiesIndex.import!.should == true }

    context do
      before do
        stub_index(:cities) do
          define_type City do
            field :name, type: 'object'
          end
        end.tap(&:create!)
      end

      specify { expect { CitiesIndex.import!(city: dummy_cities) }.to raise_error Chewy::FailedImport }
    end
  end

  describe '.reset!' do
    before do
      stub_model(:city)
      stub_index(:cities) do
        define_type City
      end
    end

    before { City.create!(name: 'Moscow') }

    specify { CitiesIndex.reset!.should be_true }
    specify { CitiesIndex.reset!('2013').should be_true }

    context do
      before { CitiesIndex.reset! }

      specify { CitiesIndex.all.should have(1).item }
      specify { CitiesIndex.aliases.should == [] }
      specify { CitiesIndex.indexes.should == [] }

      context do
        before { CitiesIndex.reset!('2013') }

        specify { CitiesIndex.all.should have(1).item }
        specify { CitiesIndex.aliases.should == [] }
        specify { CitiesIndex.indexes.should == ['cities_2013'] }
      end

      context do
        before { CitiesIndex.reset! }

        specify { CitiesIndex.all.should have(1).item }
        specify { CitiesIndex.aliases.should == [] }
        specify { CitiesIndex.indexes.should == [] }
      end
    end

    context do
      before { CitiesIndex.reset!('2013') }

      specify { CitiesIndex.all.should have(1).item }
      specify { CitiesIndex.aliases.should == [] }
      specify { CitiesIndex.indexes.should == ['cities_2013'] }

      context do
        before { CitiesIndex.reset!('2014') }

        specify { CitiesIndex.all.should have(1).item }
        specify { CitiesIndex.aliases.should == [] }
        specify { CitiesIndex.indexes.should == ['cities_2014'] }
        specify { Chewy.client.indices.exists(index: 'cities_2013').should be_false }
      end

      context do
        before { CitiesIndex.reset! }

        specify { CitiesIndex.all.should have(1).item }
        specify { CitiesIndex.aliases.should == [] }
        specify { CitiesIndex.indexes.should == [] }
        specify { Chewy.client.indices.exists(index: 'cities_2013').should be_false }
      end
    end
  end
end

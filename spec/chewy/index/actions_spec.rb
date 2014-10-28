require 'spec_helper'

describe Chewy::Index::Actions do
  before { Chewy.massacre }

  before { stub_index :dummies }

  describe '.exists?' do
    specify { DummiesIndex.exists?.should eq(false) }

    context do
      before { DummiesIndex.create }
      specify { DummiesIndex.exists?.should eq(true) }
    end
  end

  describe '.create' do
    specify { DummiesIndex.create["acknowledged"].should eq(true) }
    specify { DummiesIndex.create('2013')["acknowledged"].should eq(true) }

    context do
      before { DummiesIndex.create }
      specify { DummiesIndex.create.should eq(false) }
      specify { DummiesIndex.create('2013').should eq(false) }
    end

    context do
      before { DummiesIndex.create '2013' }
      specify { Chewy.client.indices.exists(index: 'dummies').should eq(true) }
      specify { Chewy.client.indices.exists(index: 'dummies_2013').should eq(true) }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == ['dummies_2013'] }
      specify { DummiesIndex.create('2013').should eq(false) }
      specify { DummiesIndex.create('2014')["acknowledged"].should eq(true) }

      context do
        before { DummiesIndex.create '2014' }
        specify { DummiesIndex.indexes.should =~ ['dummies_2013', 'dummies_2014'] }
      end
    end

    context do
      before { DummiesIndex.create '2013', alias: false }
      specify { Chewy.client.indices.exists(index: 'dummies').should eq(false) }
      specify { Chewy.client.indices.exists(index: 'dummies_2013').should eq(true) }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == [] }
    end
  end

  describe '.create!' do
    specify { DummiesIndex.create!["acknowledged"].should eq(true) }
    specify { DummiesIndex.create!('2013')["acknowledged"].should eq(true) }

    context do
      before { DummiesIndex.create }
      specify { expect { DummiesIndex.create! }.to raise_error }
      specify { expect { DummiesIndex.create!('2013') }.to raise_error }
    end

    context do
      before { DummiesIndex.create! '2013' }
      specify { Chewy.client.indices.exists(index: 'dummies').should eq(true) }
      specify { Chewy.client.indices.exists(index: 'dummies_2013').should eq(true) }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == ['dummies_2013'] }
      specify { expect { DummiesIndex.create!('2013') }.to raise_error }
      specify { DummiesIndex.create!('2014')["acknowledged"].should eq(true) }

      context do
        before { DummiesIndex.create! '2014' }
        specify { DummiesIndex.indexes.should =~ ['dummies_2013', 'dummies_2014'] }
      end
    end

    context do
      before { DummiesIndex.create! '2013', alias: false }
      specify { Chewy.client.indices.exists(index: 'dummies').should eq(false) }
      specify { Chewy.client.indices.exists(index: 'dummies_2013').should eq(true) }
      specify { DummiesIndex.aliases.should == [] }
      specify { DummiesIndex.indexes.should == [] }
    end
  end

  describe '.delete' do
    specify { DummiesIndex.delete.should eq(false) }
    specify { DummiesIndex.delete('dummies_2013').should eq(false) }

    context do
      before { DummiesIndex.create }
      specify { DummiesIndex.delete["acknowledged"].should eq(true) }

      context do
        before { DummiesIndex.delete }
        specify { Chewy.client.indices.exists(index: 'dummies').should eq(false) }
      end
    end

    context do
      before { DummiesIndex.create '2013' }
      specify { DummiesIndex.delete('2013')["acknowledged"].should eq(true) }

      context do
        before { DummiesIndex.delete('2013') }
        specify { Chewy.client.indices.exists(index: 'dummies').should eq(false) }
        specify { Chewy.client.indices.exists(index: 'dummies_2013').should eq(false) }
      end

      context do
        before { DummiesIndex.create '2014' }
        specify { DummiesIndex.delete["acknowledged"].should eq(true) }

        context do
          before { DummiesIndex.delete }
          specify { Chewy.client.indices.exists(index: 'dummies').should eq(false) }
          specify { Chewy.client.indices.exists(index: 'dummies_2013').should eq(false) }
          specify { Chewy.client.indices.exists(index: 'dummies_2014').should eq(false) }
        end

        context do
          before { DummiesIndex.delete('2014') }
          specify { Chewy.client.indices.exists(index: 'dummies').should eq(true) }
          specify { Chewy.client.indices.exists(index: 'dummies_2013').should eq(true) }
          specify { Chewy.client.indices.exists(index: 'dummies_2014').should eq(false) }
        end
      end
    end
  end

  describe '.delete!' do
    specify { expect { DummiesIndex.delete! }.to raise_error }
    specify { expect { DummiesIndex.delete!('2013') }.to raise_error }

    context do
      before { DummiesIndex.create }
      specify { DummiesIndex.delete!["acknowledged"].should eq(true) }

      context do
        before { DummiesIndex.delete! }
        specify { Chewy.client.indices.exists(index: 'dummies').should eq(false) }
      end
    end

    context do
      before { DummiesIndex.create '2013' }
      specify { DummiesIndex.delete!('2013')["acknowledged"].should eq(true) }

      context do
        before { DummiesIndex.delete!('2013') }
        specify { Chewy.client.indices.exists(index: 'dummies').should eq(false) }
        specify { Chewy.client.indices.exists(index: 'dummies_2013').should eq(false) }
      end

      context do
        before { DummiesIndex.create '2014' }
        specify { DummiesIndex.delete!["acknowledged"].should eq(true) }

        context do
          before { DummiesIndex.delete! }
          specify { Chewy.client.indices.exists(index: 'dummies').should eq(false) }
          specify { Chewy.client.indices.exists(index: 'dummies_2013').should eq(false) }
          specify { Chewy.client.indices.exists(index: 'dummies_2014').should eq(false) }
        end

        context do
          before { DummiesIndex.delete!('2014') }
          specify { Chewy.client.indices.exists(index: 'dummies').should eq(true) }
          specify { Chewy.client.indices.exists(index: 'dummies_2013').should eq(true) }
          specify { Chewy.client.indices.exists(index: 'dummies_2014').should eq(false) }
        end
      end
    end
  end

  describe '.purge' do
    specify { DummiesIndex.purge["acknowledged"].should eq(true) }
    specify { DummiesIndex.purge('2013')["acknowledged"].should eq(true) }

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
    specify { DummiesIndex.purge!["acknowledged"].should eq(true) }
    specify { DummiesIndex.purge!('2013')["acknowledged"].should eq(true) }

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

  describe '.import', :orm do
    before do
      stub_model(:city)
      stub_index(:cities) do
        define_type City
      end
    end
    let!(:dummy_cities) { 3.times.map { |i| City.create(id: i + 1, name: "name#{i}") } }

    specify { CitiesIndex.import.should == true }

    context do
      before do
        stub_index(:cities) do
          define_type City do
            field :name, type: 'object'
          end
        end
      end

      specify { CitiesIndex.import(city: dummy_cities).should == false }
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

    specify { CitiesIndex.import!.should == true }

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

    specify { CitiesIndex.reset!.should eq(true) }
    specify { CitiesIndex.reset!('2013').should eq(true) }

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
        specify { Chewy.client.indices.exists(index: 'cities_2013').should eq(false) }
      end

      context do
        before { CitiesIndex.reset! }

        specify { CitiesIndex.all.should have(1).item }
        specify { CitiesIndex.aliases.should == [] }
        specify { CitiesIndex.indexes.should == [] }
        specify { Chewy.client.indices.exists(index: 'cities_2013').should eq(false) }
      end
    end
  end
end

require 'spec_helper'

describe Chewy::Index::Aliases do
  include ClassHelpers
  before { Chewy::Index.client.indices.delete }

  before { stub_index :dummies }

  describe '.indexes' do
    specify { DummiesIndex.indexes.should == [] }

    context do
      before { DummiesIndex.create! }
      specify { DummiesIndex.indexes.should == [] }
    end

    context do
      before { DummiesIndex.create! }
      before { Chewy.client.indices.put_alias index: 'dummies', name: 'dummies_2013' }
      specify { DummiesIndex.indexes.should == [] }
    end

    context do
      before { DummiesIndex.create! '2013' }
      before { DummiesIndex.create! '2014' }
      specify { DummiesIndex.indexes.should =~ ['dummies_2013', 'dummies_2014'] }
    end
  end

  describe '.aliases' do
    specify { DummiesIndex.aliases.should == [] }

    context do
      before { DummiesIndex.create! }
      specify { DummiesIndex.aliases.should == [] }
    end

    context do
      before { DummiesIndex.create! }
      before { Chewy.client.indices.put_alias index: 'dummies', name: 'dummies_2013' }
      before { Chewy.client.indices.put_alias index: 'dummies', name: 'dummies_2014' }
      specify { DummiesIndex.aliases.should =~ ['dummies_2013', 'dummies_2014'] }
    end

    context do
      before { DummiesIndex.create! '2013' }
      specify { DummiesIndex.aliases.should == [] }
    end
  end
end

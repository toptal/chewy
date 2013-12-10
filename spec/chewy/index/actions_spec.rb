require 'spec_helper'

describe Chewy::Index::Actions do
  include ClassHelpers
  before { Chewy::Index.client.indices.delete }

  before { stub_index :dummies }

  describe '.index_exists?' do
    specify { DummiesIndex.index_exists?.should be_false }

    context do
      before { DummiesIndex.index_create }
      specify { DummiesIndex.index_exists?.should be_true }
    end
  end

  describe '.index_create' do
    specify { DummiesIndex.index_create.should be_true }

    context do
      before { DummiesIndex.index_create }
      specify { DummiesIndex.index_create.should be_false }
    end
  end

  describe '.index_create!' do
    specify { expect { DummiesIndex.index_create! }.not_to raise_error }

    context do
      before { DummiesIndex.index_create }
      specify { expect { DummiesIndex.index_create! }.to raise_error }
    end
  end

  describe '.index_delete' do
    specify { DummiesIndex.index_delete.should be_false }

    context do
      before { DummiesIndex.index_create }
      specify { DummiesIndex.index_delete.should be_true }
    end
  end

  describe '.index_delete!' do
    specify { expect { DummiesIndex.index_delete! }.to raise_error }

    context do
      before { DummiesIndex.index_create }
      specify { expect { DummiesIndex.index_delete! }.not_to raise_error }
    end
  end
end

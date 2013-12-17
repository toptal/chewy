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

    context do
      before { DummiesIndex.create }
      specify { DummiesIndex.create.should be_false }
    end
  end

  describe '.create!' do
    specify { expect { DummiesIndex.create! }.not_to raise_error }

    context do
      before { DummiesIndex.create }
      specify { expect { DummiesIndex.create! }.to raise_error }
    end
  end

  describe '.delete' do
    specify { DummiesIndex.delete.should be_false }

    context do
      before { DummiesIndex.create }
      specify { DummiesIndex.delete.should be_true }
    end
  end

  describe '.delete!' do
    specify { expect { DummiesIndex.delete! }.to raise_error }

    context do
      before { DummiesIndex.create }
      specify { expect { DummiesIndex.delete! }.not_to raise_error }
    end
  end
end

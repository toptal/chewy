require 'spec_helper'

describe Chewy::Index::Actions do
  include ClassHelpers
  before { Chewy::Index.client.indices.delete }

  let(:dummy_index) do
    index_class do
      index_name :dummy_index
    end
  end

  describe '.index_exists?' do
    specify { dummy_index.index_exists?.should be_false }

    context do
      before { dummy_index.index_create }
      specify { dummy_index.index_exists?.should be_true }
    end
  end

  describe '.index_create' do
    specify { dummy_index.index_create.should be_true }

    context do
      before { dummy_index.index_create }
      specify { dummy_index.index_create.should be_false }
    end
  end

  describe '.index_create!' do
    specify { expect { dummy_index.index_create! }.not_to raise_error }

    context do
      before { dummy_index.index_create }
      specify { expect { dummy_index.index_create! }.to raise_error }
    end
  end

  describe '.index_delete' do
    specify { dummy_index.index_delete.should be_false }

    context do
      before { dummy_index.index_create }
      specify { dummy_index.index_delete.should be_true }
    end
  end

  describe '.index_delete!' do
    specify { expect { dummy_index.index_delete! }.to raise_error }

    context do
      before { dummy_index.index_create }
      specify { expect { dummy_index.index_delete! }.not_to raise_error }
    end
  end
end

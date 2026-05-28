require 'spec_helper'

describe Chewy::Index::Actions do
  before { drop_indices }

  before do
    stub_index :dummies
    stub_index :dummies_suffixed
  end

  describe '.journal' do
    specify { expect(DummiesIndex.journal).to be_a(Chewy::Journal) }
  end
end

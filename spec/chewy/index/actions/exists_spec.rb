require 'spec_helper'

describe Chewy::Index::Actions do
  before { drop_indices }

  before do
    stub_index :dummies
    stub_index :dummies_suffixed
  end

  describe '.exists?' do
    specify { expect(DummiesIndex.exists?).to eq(false) }

    context do
      before { DummiesIndex.create }
      specify { expect(DummiesIndex.exists?).to eq(true) }
    end

    context 'with suffix' do
      before { DummiesIndex.create('2024') }
      specify { expect(DummiesIndex.exists?).to eq(true) }
      specify { expect(DummiesIndex.exists?('2024')).to eq(true) }
      specify { expect(DummiesIndex.exists?('2025')).to eq(false) }
    end

    context 'suffixed only, no alias' do
      before { DummiesIndex.create('2024', alias: false) }
      specify { expect(DummiesIndex.exists?).to eq(false) }
      specify { expect(DummiesIndex.exists?('2024')).to eq(true) }
    end
  end
end

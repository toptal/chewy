require 'spec_helper'

describe Chewy::Index::Actions do
  before { drop_indices }

  before do
    stub_index :dummies
    stub_index :dummies_suffixed
  end

  describe '.create!' do
    specify { expect(DummiesIndex.create!['acknowledged']).to eq(true) }
    specify { expect(DummiesIndex.create!('2013')['acknowledged']).to eq(true) }

    context do
      before do
        DummiesIndex.create
        DummiesSuffixedIndex.create 'should_not_appear'
      end

      specify do
        expect do
          DummiesIndex.create!
        end.to raise_error(Elastic::Transport::Transport::Errors::BadRequest).with_message(/already exists.*dummies/)
      end
      specify do
        expect do
          DummiesIndex.create!('2013')
        end.to raise_error(Elastic::Transport::Transport::Errors::BadRequest).with_message(/Invalid alias name \[dummies\]/)
      end
    end

    context do
      before do
        DummiesIndex.create! '2013'
        DummiesSuffixedIndex.create! 'should_not_appear'
      end

      specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(true) }
      specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(true) }
      specify { expect(DummiesIndex.aliases).to eq(['dummies']) }
      specify { expect(DummiesIndex.indexes).to eq(['dummies_2013']) }
      specify do
        expect do
          DummiesIndex.create!('2013')
        end.to raise_error(Elastic::Transport::Transport::Errors::BadRequest).with_message(/already exists.*dummies_2013/)
      end
      specify { expect(DummiesIndex.create!('2014')['acknowledged']).to eq(true) }

      context do
        before { DummiesIndex.create! '2014' }

        specify { expect(DummiesIndex.indexes).to match_array(%w[dummies_2013 dummies_2014]) }
      end
    end

    context do
      before do
        DummiesIndex.create! '2013', alias: false
        DummiesSuffixedIndex.create! 'should_not_appear'
      end

      specify { expect(Chewy.client.indices.exists(index: 'dummies')).to eq(false) }
      specify { expect(Chewy.client.indices.exists(index: 'dummies_2013')).to eq(true) }
      specify { expect(DummiesIndex.aliases).to eq([]) }
      specify { expect(DummiesIndex.indexes).to eq([]) }
      specify { expect(DummiesIndex.exists?).to eq(false) }
      # Unfortunately, without alias we can't figure out that this dummies_2013 index is related to DummiesIndex
      # it would be awesome to have the following specs passing
      # specify { expect(DummiesIndex.indexes).to eq(['dummies_2013']) }
      # specify { expect(DummiesIndex.exists?).to eq(true) }
    end
  end
end

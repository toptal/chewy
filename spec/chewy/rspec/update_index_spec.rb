require 'spec_helper'

describe :update_index do
  before { Chewy.massacre }

  before do
    stub_index(:dummies) do
      define_type :dummy do
        root value: ->(o){{}}
      end
    end
  end

  specify { expect {  }.not_to update_index(DummiesIndex::Dummy) }
  specify { expect { DummiesIndex::Dummy.bulk body: [] }.not_to update_index(DummiesIndex::Dummy) }

  specify { expect { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42}}] }.not_to update_index(DummiesIndex::Dummy) }
    .to fail_with(/Expected index .* not to be updated, but it was with/) }

  context do
    let(:expectation) do
      expect { expect {
        DummiesIndex::Dummy.bulk body: [{index: {_id: 42}}, {index: {_id: 41}}, {index: {_id: 42}}]
      }.not_to update_index(DummiesIndex::Dummy) }
    end

    specify { expectation.to fail_matching 'document id `42` (2 times)' }
    specify { expectation.to fail_matching 'document id `41` (1 times)' }
  end

  context '#only' do
    specify { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 41, data: {}}}] }
      .to update_index(DummiesIndex::Dummy).and_reindex(41, 42).only }
    specify { expect { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 41, data: {}}}] }
      .to update_index(DummiesIndex::Dummy).and_reindex(41).only }
        .to fail_matching 'to update documents ["41"] only, but ["42"] was updated also' }
    specify { expect { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 41, data: {}}}] }
      .to update_index(DummiesIndex::Dummy).and_reindex(41, times: 2).only }
        .to fail_matching 'to update documents ["41"] only, but ["42"] was updated also' }

    specify { expect { DummiesIndex::Dummy.bulk body: [{delete: {_id: 42}}, {delete: {_id: 41}}] }
      .to update_index(DummiesIndex::Dummy).and_delete(41, 42).only }
    specify { expect { expect { DummiesIndex::Dummy.bulk body: [{delete: {_id: 42}}, {delete: {_id: 41}}] }
      .to update_index(DummiesIndex::Dummy).and_delete(41).only }
        .to fail_matching 'to delete documents ["41"] only, but ["42"] was deleted also' }
    specify { expect { expect { DummiesIndex::Dummy.bulk body: [{delete: {_id: 42}}, {delete: {_id: 41}}] }
      .to update_index(DummiesIndex::Dummy).and_delete(41, times: 2).only }
        .to fail_matching 'to delete documents ["41"] only, but ["42"] was deleted also' }
  end

  context '#and_reindex' do
    specify { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42}}] }.to update_index(DummiesIndex::Dummy) }
    specify { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}] }
      .to update_index(DummiesIndex::Dummy).and_reindex(42) }
    specify { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 43, data: {}}}] }
      .to update_index(DummiesIndex::Dummy).and_reindex(double(id: 42)) }
    specify { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 43, data: {}}}] }
      .to update_index(DummiesIndex::Dummy).and_reindex(double(id: 42), double(id: 43)) }
    specify { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 43, data: {}}}] }
      .to update_index(DummiesIndex::Dummy).and_reindex([double(id: 42), 43]) }

    specify do
      expect {
        expect {
          DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 43, data: {}}}]
        }.to update_index(DummiesIndex::Dummy).and_reindex([44, 43])
      }.to fail_matching 'Expected document with id `44` to be reindexed, but it was not'
    end

    context do
      let(:expectation) do
        expect { expect {
          DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 43, data: {}}}]
        }.to update_index(DummiesIndex::Dummy).and_reindex(44, double(id: 47)) }
      end

      specify { expectation.to fail_matching('Expected document with id `44` to be reindexed, but it was not') }
      specify { expectation.to fail_matching('Expected document with id `47` to be reindexed, but it was not') }
    end

    context ':times' do
      specify { expect {
        DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 43, data: {}}}]
        DummiesIndex::Dummy.bulk body: [{index: {_id: 43, data: {}}}, {index: {_id: 44, data: {}}}]
      }.to update_index(DummiesIndex::Dummy).and_reindex(42, 44, times: 1).and_reindex(43, times: 2) }

      specify { expect {
        expect {
          DummiesIndex::Dummy.bulk body: [{index: {_id: 43, data: {a: '1'}}}]
        }.to update_index(DummiesIndex::Dummy).and_reindex(42, times: 3)
      }.to fail_matching('Expected document with id `42` to be reindexed, but it was not') }

      context do
        let(:expectation) do
          expect { expect {
            DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {index: {_id: 43, data: {}}}]
            DummiesIndex::Dummy.bulk body: [{index: {_id: 43, data: {}}}, {index: {_id: 44, data: {}}}]
          }.to update_index(DummiesIndex::Dummy).and_reindex(42, times: 3).and_reindex(44, 43, times: 4) }
        end

        specify { expectation.to fail_matching 'Expected document with id `44` to be reindexed' }
        specify { expectation.to fail_matching 'Expected document with id `43` to be reindexed' }
        specify { expectation.to fail_matching '3 times, but was reindexed 1 times' }
        specify { expectation.to fail_matching '4 times, but was reindexed 2 times' }
      end
    end

    context ':with' do
      specify { expect {
        DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {a: '1'}}}, {index: {_id: 42, data: {'a' => 2}}}]
      }.to update_index(DummiesIndex::Dummy).and_reindex(42, with: {a: 2}) }

      specify { expect {
        DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {a: '1'}}}, {index: {_id: 42, data: {'b' => 2}}}]
      }.to update_index(DummiesIndex::Dummy).and_reindex(42, with: {a: '1', b: 2}) }

      specify { expect {
        expect {
          DummiesIndex::Dummy.bulk body: [{index: {_id: 43, data: {a: '1'}}}]
        }.to update_index(DummiesIndex::Dummy).and_reindex(42, with: {a: 1})
      }.to fail_matching('Expected document with id `42` to be reindexed, but it was not') }

      [
        [{a: ['one', 'two']}, {a: ['one', 'two']}],
        [{a: ['one', 'two']}, {a: ['two', 'one']}],
        [{a: ['one', 'one', 'two']}, {a: ['one', 'two', 'one']}],
        [{a: {b: ['one', 'one', 'two']}}, {a: {b: ['one', 'two', 'one']}}],
        [{a: 1, b: 1}, {a: 1}]
      ].each do |(data, with)|
        specify { expect {
          DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: data}}]
        }.to update_index(DummiesIndex::Dummy).and_reindex(42, with: with) }
      end

      [
        [{a: ['one', 'two']}, {a: ['one', 'one', 'two']}],
        [{a: ['one', 'one', 'two']}, {a: ['one', 'two']}],
        [{a: ['one', 'two']}, {a: 1}],
        [{a: 1}, {a: ['one', 'two']}],
        [{a: 1}, {a: 1, b: 1}]
      ].each do |(data, with)|
        specify { expect {
          expect {
            DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: data}}]
          }.to update_index(DummiesIndex::Dummy).and_reindex(42, with: with)
        }.to fail_matching('Expected document with id `42` to be reindexed') }
      end

      context do
        let(:expectation) do
          expect { expect {
            DummiesIndex::Dummy.bulk body: [{index: {_id: 43, data: {a: '1'}}}, {index: {_id: 42, data: {'a' => 2}}}]
          }.to update_index(DummiesIndex::Dummy).and_reindex(43, times: 2, with: {a: 2}) }
        end

        specify { expectation.to fail_matching 'Expected document with id `43` to be reindexed' }
        specify { expectation.to fail_matching '2 times, but was reindexed 1 times' }
        specify { expectation.to fail_matching 'with {:a=>2}, but it was reindexed with {:a=>"1"}' }
      end
    end
  end

  context '#and_delete' do
    specify { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {delete: {_id: 43}}] }
      .to update_index(DummiesIndex::Dummy).and_reindex(42).and_delete(double(id: 43)) }
    specify { expect { DummiesIndex::Dummy.bulk body: [{delete: {_id: 42}}, {delete: {_id: 43}}] }
      .to update_index(DummiesIndex::Dummy).and_delete(42).and_delete(double(id: 43)) }
    specify { expect { DummiesIndex::Dummy.bulk body: [{delete: {_id: 42}}, {delete: {_id: 43}}] }
      .to update_index(DummiesIndex::Dummy).and_delete(42, double(id: 43)) }
    specify { expect { DummiesIndex::Dummy.bulk body: [{delete: {_id: 42}}, {delete: {_id: 43}}] }
      .to update_index(DummiesIndex::Dummy).and_delete([43, double(id: 42)]) }

    context do
      let(:expectation) do
        expect { expect { DummiesIndex::Dummy.bulk body: [{index: {_id: 42, data: {}}}, {delete: {_id: 43}}] }
          .to update_index(DummiesIndex::Dummy).and_reindex(43).and_delete(double(id: 42)) }
      end

      specify { expectation.to fail_matching 'Expected document with id `43` to be reindexed, but it was not' }
      specify { expectation.to fail_matching 'Expected document with id `42` to be deleted, but it was not' }
    end

    context do
      let(:expectation) do
        expect { expect { DummiesIndex::Dummy.bulk body: [{delete: {_id: 42, data: {}}}, {delete: {_id: 42}}] }
          .to update_index(DummiesIndex::Dummy).and_delete(44, times: 2).and_delete(double(id: 42), times: 3) }
      end

      specify { expectation.to fail_matching 'Expected document with id `44` to be deleted, but it was not' }
      specify { expectation.to fail_matching 'Expected document with id `42` to be deleted' }
      specify { expectation.to fail_matching '3 times, but was deleted 2 times' }
    end
  end
end

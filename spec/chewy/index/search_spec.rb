require 'spec_helper'

describe Chewy::Index::Search do
  include ClassHelpers

  before do
    stub_index(:products) do
      define_type :product
      define_type :product2
    end
  end

  let(:product) { ProductsIndex::Product }

  describe '.scoped' do
    specify { product.scoped.should be_a Chewy::Query }
    specify { product.scoped.object_id.should_not == product.scoped.object_id }
    specify { product.scoped.should == product.scoped }
  end

  describe '.search_string' do
    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(q: 'hello')).twice
      ProductsIndex.search_string('hello')
      product.search_string('hello')
    end

    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(explain: true)).twice
      ProductsIndex.search_string('hello', explain: true)
      product.search_string('hello', explain: true)
    end

    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(index: 'products', type: ['product', 'product2']))
      ProductsIndex.search_string('hello')
    end

    specify do
      expect(ProductsIndex.client).to receive(:search).with(hash_including(index: 'products', type: 'product'))
      product.search_string('hello')
    end
  end

  describe '.search_index' do
    specify { ProductsIndex.search_index.should == ProductsIndex }
    specify { product.search_index.should == ProductsIndex }
  end

  describe '.search_type' do
    specify { ProductsIndex.search_type.should == ['product', 'product2'] }
    specify { product.search_type.should == 'product' }
  end
end

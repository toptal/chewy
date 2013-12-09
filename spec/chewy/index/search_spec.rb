require 'spec_helper'

describe Chewy::Index::Search do
  include ClassHelpers

  let!(:product) { stub_const('ProductType', type_class(:product)) }
  let!(:products) { index_class(:products) do
    define_type ProductType
    define_type(:product2) {}
  end }

  describe '.search' do
    specify do
      product.search.should be_a Chewy::Query
    end
  end

  describe '.search_string' do
    specify do
      expect(products.client).to receive(:search).with(hash_including(q: 'hello')).twice
      products.search_string('hello')
      product.search_string('hello')
    end

    specify do
      expect(products.client).to receive(:search).with(hash_including(explain: true)).twice
      products.search_string('hello', explain: true)
      product.search_string('hello', explain: true)
    end

    specify do
      expect(products.client).to receive(:search).with(hash_including(index: 'products', type: ['product', 'product2']))
      products.search_string('hello')
    end

    specify do
      expect(products.client).to receive(:search).with(hash_including(index: 'products', type: 'product'))
      product.search_string('hello')
    end
  end

  describe '.search_index' do
    specify { products.search_index.should == products }
    specify { product.search_index.should == products }
  end

  describe '.search_type' do
    specify { products.search_type.should == ['product', 'product2'] }
    specify { product.search_type.should == 'product' }
  end
end

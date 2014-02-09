require 'spec_helper'

describe Chewy::Type::Adapter::Object do
  before { stub_class(:product) }

  describe '#name' do
    specify { described_class.new('product').name.should == 'Product' }
    specify { described_class.new(:products).name.should == 'Products' }
    specify { described_class.new(Product).name.should == 'Product' }
    specify { described_class.new(Product, name: 'house').name.should == 'House' }
  end

  describe '#type_name' do
    specify { described_class.new('product').type_name.should == 'product' }
    specify { described_class.new(:products).type_name.should == 'products' }
    specify { described_class.new(Product).type_name.should == 'product' }
    specify { described_class.new(Product, name: 'house').type_name.should == 'house' }
  end

  describe '#import' do
    def import(*args)
      result = []
      subject.import(*args) { |data| result.push data }
      result
    end

    specify { subject.import(3.times.map { |i| double }) { |data| true }.should be_true }
    specify { subject.import(3.times.map { |i| double }) { |data| false }.should be_false }

    context do
      let(:objects) { 3.times.map { |i| double } }
      let(:deleted) { 2.times.map { |i| double(destroyed?: true) } }
      subject { described_class.new('product') }

      specify { import.should == [] }
      specify { import(objects).should == [{index: objects}] }
      specify { import(objects, batch_size: 2)
          .should == [{index: objects.first(2)}, {index: objects.last(1)}] }
      specify { import(objects, deleted).should == [{index: objects, delete: deleted}] }
      specify { import(objects, deleted, batch_size: 2).should == [
          {index: objects.first(2)},
          {index: objects.last(1), delete: deleted.first(1)},
          {delete: deleted.last(1)}] }
    end

    context do
      let(:products) { 3.times.map { |i| double.tap { |product|
        product.stub(:is_a?).with(Product).and_return(true)
      } } }
      let(:non_product) { double }
      subject { described_class.new(Product) }

      specify { import(products).should == [{index: products}] }
      specify { expect { import(products, non_product) {} }.to raise_error }
    end

    context 'error handling' do
      let(:products) { 3.times.map { |i| double.tap { |product| product.stub(rating: i.next) } } }
      let(:deleted) { 2.times.map { |i| double(destroyed?: true, rating: i + 4) } }
      subject { described_class.new('product') }

      let(:data_comparer) do
        ->(n, data) { (data[:index] || data[:delete]).first.rating != n }
      end

      specify { subject.import(products, deleted) { |data| true }.should be_true }
      specify { subject.import(products, deleted) { |data| false }.should be_false }
      specify { subject.import(products, deleted, batch_size: 1, &data_comparer.curry[1]).should be_false }
      specify { subject.import(products, deleted, batch_size: 1, &data_comparer.curry[2]).should be_false }
      specify { subject.import(products, deleted, batch_size: 1, &data_comparer.curry[3]).should be_false }
      specify { subject.import(products, deleted, batch_size: 1, &data_comparer.curry[4]).should be_false }
      specify { subject.import(products, deleted, batch_size: 1, &data_comparer.curry[5]).should be_false }
    end
  end

  describe '#load' do
    context do
      subject { described_class.new('product') }
      let(:objects) { 3.times.map { |i| double } }

      specify { subject.load(objects).should == objects }
    end

    context do
      before { Product.stub(:wrap) { |object| object.stub(wrapped?: true); object } }
      subject { described_class.new(Product) }
      let(:objects) { 3.times.map { |i| double(wrapped?: false) } }

      specify { subject.load(objects).should satisfy { |objects| objects.all?(&:wrapped?) } }
    end

    context do
      before { Product.stub(:wrap) { |object| nil } }
      subject { described_class.new(Product) }
      let(:objects) { 3.times.map { |i| double(wrapped?: false) } }

      specify { subject.load(objects).should satisfy { |objects| objects.all?(&:nil?) } }
    end
  end
end

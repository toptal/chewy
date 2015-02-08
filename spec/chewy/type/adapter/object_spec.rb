require 'spec_helper'

describe Chewy::Type::Adapter::Object do
  before { stub_class(:product) }

  describe '#name' do
    specify { expect(described_class.new('product').name).to eq('Product') }
    specify { expect(described_class.new(:products).name).to eq('Products') }
    specify { expect(described_class.new(Product).name).to eq('Product') }
    specify { expect(described_class.new(Product, name: 'house').name).to eq('House') }

    context do
      before { stub_class('namespace/product') }

      specify { expect(described_class.new(Namespace::Product).name).to eq('Product') }
    end
  end

  describe '#type_name' do
    specify { expect(described_class.new('product').type_name).to eq('product') }
    specify { expect(described_class.new(:products).type_name).to eq('products') }
    specify { expect(described_class.new(Product).type_name).to eq('product') }
    specify { expect(described_class.new(Product, name: 'house').type_name).to eq('house') }

    context do
      before { stub_class('namespace/product') }

      specify { expect(described_class.new(Namespace::Product).type_name).to eq('product') }
    end
  end

  describe '#import' do
    def import(*args)
      result = []
      subject.import(*args) { |data| result.push data }
      result
    end

    specify { expect(subject.import(3.times.map { |i| double }) { |data| true }).to eq(true) }
    specify { expect(subject.import(3.times.map { |i| double }) { |data| false }).to eq(false) }

    context do
      let(:objects) { 3.times.map { |i| double } }
      let(:deleted) { 2.times.map { |i| double(destroyed?: true) } }
      subject { described_class.new('product') }

      specify { expect(import).to eq([]) }
      specify { expect(import nil).to eq([]) }

      specify { expect(import(objects)).to eq([{index: objects}]) }
      specify { expect(import(objects, batch_size: 2))
          .to eq([{index: objects.first(2)}, {index: objects.last(1)}]) }
      specify { expect(import(objects, deleted)).to eq([{index: objects, delete: deleted}]) }
      specify { expect(import(objects, deleted, batch_size: 2)).to eq([
          {index: objects.first(2)},
          {index: objects.last(1), delete: deleted.first(1)},
          {delete: deleted.last(1)}]) }

      specify { expect(import(objects.first, nil)).to eq([{index: [objects.first]}]) }

      context 'initial data' do
        subject { described_class.new ->{ objects } }

        specify { expect(import).to eq([{index: objects}]) }
        specify { expect(import nil).to eq([]) }

        specify { expect(import(objects[0..1])).to eq([{index: objects[0..1]}]) }
        specify { expect(import(batch_size: 2))
          .to eq([{index: objects.first(2)}, {index: objects.last(1)}]) }
      end

      context do
        let(:deleted) { 2.times.map { |i| double(delete_from_index?: true, destroyed?: true) } }
        specify { expect(import(deleted)).to eq([{delete: deleted}]) }
      end

      context do
        let(:deleted) { 2.times.map { |i| double(delete_from_index?: true, destroyed?: false) } }
        specify { expect(import(deleted)).to eq([{delete: deleted}]) }
      end


      context do
        let(:deleted) { 2.times.map { |i| double(delete_from_index?: false, destroyed?: true) } }
        specify { expect(import(deleted)).to eq([{delete: deleted}]) }
      end

      context do
        let(:deleted) { 2.times.map { |i| double(delete_from_index?: false, destroyed?: false) } }
        specify { expect(import(deleted)).to eq([{index: deleted}]) }
      end
    end

    context 'error handling' do
      let(:products) { 3.times.map { |i| double.tap { |product| allow(product).to receive_messages(rating: i.next) } } }
      let(:deleted) { 2.times.map { |i| double(destroyed?: true, rating: i + 4) } }
      subject { described_class.new('product') }

      let(:data_comparer) do
        ->(n, data) { (data[:index] || data[:delete]).first.rating != n }
      end

      specify { expect(subject.import(products, deleted) { |data| true }).to eq(true) }
      specify { expect(subject.import(products, deleted) { |data| false }).to eq(false) }
      specify { expect(subject.import(products, deleted, batch_size: 1, &data_comparer.curry[1])).to eq(false) }
      specify { expect(subject.import(products, deleted, batch_size: 1, &data_comparer.curry[2])).to eq(false) }
      specify { expect(subject.import(products, deleted, batch_size: 1, &data_comparer.curry[3])).to eq(false) }
      specify { expect(subject.import(products, deleted, batch_size: 1, &data_comparer.curry[4])).to eq(false) }
      specify { expect(subject.import(products, deleted, batch_size: 1, &data_comparer.curry[5])).to eq(false) }
    end
  end

  describe '#load' do
    context do
      subject { described_class.new('product') }
      let(:objects) { 3.times.map { |i| double } }

      specify { expect(subject.load(objects)).to eq(objects) }
    end

    [:wrap, :load_one].each do |load_method|
      context do
        before { allow(Product).to receive(load_method) { |object| allow(object).to receive_messages(wrapped?: true); object } }
        subject { described_class.new(Product) }
        let(:objects) { 3.times.map { |i| double(wrapped?: false) } }

        specify { expect(subject.load(objects)).to satisfy { |objects| objects.all?(&:wrapped?) } }
      end

      context do
        before { allow(Product).to receive(load_method) { |object| nil } }
        subject { described_class.new(Product) }
        let(:objects) { 3.times.map { |i| double(wrapped?: false) } }

        specify { expect(subject.load(objects)).to satisfy { |objects| objects.all?(&:nil?) } }
      end
    end
  end
end

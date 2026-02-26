require 'spec_helper'

describe Chewy::Index::Adapter::Base do
  subject { described_class.new }

  describe '.accepts?' do
    specify { expect(described_class.accepts?('anything')).to be true }
  end

  describe '#name' do
    specify { expect { subject.name }.to raise_error(NotImplementedError) }
  end

  describe '#type_name' do
    before { allow(subject).to receive(:name).and_return('SomeType') }

    specify { expect(subject.type_name).to eq('some_type') }
  end

  describe '#identify' do
    specify { expect { subject.identify([]) }.to raise_error(NotImplementedError) }
  end

  describe '#import' do
    specify { expect { subject.import([]) }.to raise_error(NotImplementedError) }
  end

  describe '#import_fields' do
    specify { expect { subject.import_fields([], 1000) }.to raise_error(NotImplementedError) }
  end

  describe '#import_references' do
    specify { expect { subject.import_references(1000) }.to raise_error(NotImplementedError) }
  end

  describe '#load' do
    specify { expect { subject.load([]) }.to raise_error(NotImplementedError) }
  end

  describe '#grouped_objects' do
    let(:adapter) { described_class.new }

    context 'without delete_if' do
      before { allow(adapter).to receive(:options).and_return({}) }

      it 'groups all objects under :index' do
        objects = [double, double]
        result = adapter.send(:grouped_objects, objects)
        expect(result).to eq(index: objects)
      end
    end

    context 'with delete_if symbol' do
      let(:active_obj) { double(deleted: false) }
      let(:deleted_obj) { double(deleted: true) }

      before { allow(adapter).to receive(:options).and_return(delete_if: :deleted) }

      it 'separates objects into index and delete groups' do
        result = adapter.send(:grouped_objects, [active_obj, deleted_obj])
        expect(result[:index]).to eq([active_obj])
        expect(result[:delete]).to eq([deleted_obj])
      end
    end

    context 'with delete_if proc (arity 1)' do
      let(:obj1) { double(id: 1) }
      let(:obj2) { double(id: 2) }

      before { allow(adapter).to receive(:options).and_return(delete_if: ->(o) { o.id == 2 }) }

      it 'uses the proc to determine deletion' do
        result = adapter.send(:grouped_objects, [obj1, obj2])
        expect(result[:index]).to eq([obj1])
        expect(result[:delete]).to eq([obj2])
      end
    end

    context 'with delete_if proc (arity 0, instance_exec)' do
      let(:obj1) { double(id: 1) }
      let(:obj2) { double(id: 2) }

      before { allow(adapter).to receive(:options).and_return(delete_if: -> { id == 2 }) }

      it 'uses instance_exec to evaluate the proc' do
        result = adapter.send(:grouped_objects, [obj1, obj2])
        expect(result[:index]).to eq([obj1])
        expect(result[:delete]).to eq([obj2])
      end
    end
  end
end

require 'spec_helper'

describe Chewy::Search::Parameters::Order do
  subject { described_class.new([:foo, :bar]) }

  describe '#initialize' do
    specify { expect(described_class.new.value).to eq({}) }
    specify { expect(described_class.new(nil).value).to eq({}) }
    specify { expect(described_class.new('').value).to eq({}) }
    specify { expect(described_class.new(42).value).to eq('42' => nil) }
    specify { expect(described_class.new([42, 43]).value).to eq('42' => nil, '43' => nil) }
    specify { expect(described_class.new(a: 1).value).to eq('a' => 1) }
    specify { expect(described_class.new(['', 43, a: 1]).value).to eq('a' => 1, '43' => nil) }
  end

  describe '#replace' do
    specify do
      expect { subject.replace(foo: {}) }
        .to change { subject.value }
        .from('foo' => nil, 'bar' => nil).to('foo' => {})
    end
  end

  describe '#update' do
    specify do
      expect { subject.update(foo: {}) }
        .to change { subject.value }
        .from('foo' => nil, 'bar' => nil).to('foo' => {}, 'bar' => nil)
    end
  end

  describe '#merge' do
    specify do
      expect { subject.merge(described_class.new(foo: {})) }
        .to change { subject.value }
        .from('foo' => nil, 'bar' => nil).to('foo' => {}, 'bar' => nil)
    end
  end

  describe '#render' do
    specify { expect(described_class.new.render).to be_nil }
    specify { expect(described_class.new(:foo).render).to eq(sort: ['foo']) }
    specify { expect(described_class.new([:foo, { bar: 42 }, :baz]).render).to eq(sort: ['foo', { 'bar' => 42 }, 'baz']) }
  end
end

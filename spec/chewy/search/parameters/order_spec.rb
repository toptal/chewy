# frozen_string_literal: true

require 'spec_helper'

describe Chewy::Search::Parameters::Order do
  subject { described_class.new(%i[foo bar]) }

  describe '#initialize' do
    specify { expect(described_class.new.value).to eq([]) }
    specify { expect(described_class.new(nil).value).to eq([]) }
    specify { expect(described_class.new('').value).to eq([]) }
    specify { expect(described_class.new(42).value).to eq(['42']) }
    specify { expect(described_class.new([42, 43]).value).to eq(%w[42 43]) }
    specify { expect(described_class.new([42, 42]).value).to eq(%w[42 42]) }
    specify { expect(described_class.new([42, [43, 44]]).value).to eq(%w[42 43 44]) }
    specify { expect(described_class.new(a: 1).value).to eq([{'a' => 1}]) }
    specify { expect(described_class.new(['a', {a: 1}, {a: 2}]).value).to eq(['a', {'a' => 1}, {'a' => 2}]) }
    specify { expect(described_class.new(['', 43, {a: 1}]).value).to eq(['43', {'a' => 1}]) }
  end

  describe '#replace!' do
    specify do
      expect { subject.replace!(foo: {}) }
        .to change { subject.value }
        .from(%w[foo bar]).to([{'foo' => {}}])
    end

    specify do
      expect { subject.replace!(nil) }
        .to change { subject.value }
        .from(%w[foo bar]).to([])
    end
  end

  describe '#update!' do
    specify do
      expect { subject.update!(foo: {}) }
        .to change { subject.value }
        .from(%w[foo bar]).to(['foo', 'bar', {'foo' => {}}])
    end

    specify { expect { subject.update!(nil) }.not_to change { subject.value } }
  end

  describe '#merge!' do
    specify do
      expect { subject.merge!(described_class.new(foo: {})) }
        .to change { subject.value }
        .from(%w[foo bar]).to(['foo', 'bar', {'foo' => {}}])
    end

    specify { expect { subject.merge!(described_class.new) }.not_to change { subject.value } }
  end

  describe '#render' do
    specify { expect(described_class.new.render).to be_nil }
    specify { expect(described_class.new(:foo).render).to eq(sort: ['foo']) }
    specify { expect(described_class.new([:foo, {bar: 42}, :baz]).render).to eq(sort: ['foo', {'bar' => 42}, 'baz']) }
    specify { expect(described_class.new([:foo, {bar: 42}, {bar: 43}, :baz]).render).to eq(sort: ['foo', {'bar' => 42}, {'bar' => 43}, 'baz']) }
  end

  describe '#==' do
    specify { expect(described_class.new).to eq(described_class.new) }
    specify { expect(described_class.new(:foo)).to eq(described_class.new(:foo)) }
    specify { expect(described_class.new(:foo)).not_to eq(described_class.new(:bar)) }
    specify { expect(described_class.new(%i[foo bar])).to eq(described_class.new(%i[foo bar])) }
    specify { expect(described_class.new(%i[foo bar])).not_to eq(described_class.new(%i[bar foo])) }
    specify { expect(described_class.new(%i[foo foo])).not_to eq(described_class.new(%i[foo])) }
    specify { expect(described_class.new(foo: {a: 42})).to eq(described_class.new(foo: {a: 42})) }
    specify { expect(described_class.new(foo: {a: 42})).not_to eq(described_class.new(foo: {b: 42})) }
    specify { expect(described_class.new(['foo', {'foo' => 42}])).not_to eq(described_class.new([{'foo' => 42}, 'foo'])) }
    specify { expect(described_class.new([{'foo' => 42}, {'foo' => 43}])).not_to eq(described_class.new([{'foo' => 43}, {'foo' => 42}])) }
  end
end

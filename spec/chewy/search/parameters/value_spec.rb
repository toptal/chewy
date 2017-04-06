require 'spec_helper'

describe Chewy::Search::Parameters::Value do
  subject { described_class.new }

  describe '#initialize' do
    specify { expect(subject.value).to be_nil }
    specify { expect(described_class.new(a: 1).value).to eq(a: 1) }
  end

  describe '#==' do
    specify { expect(subject).to eq(described_class.new) }
    specify { expect(described_class.new(:foo)).to eq(described_class.new(:foo)) }
    specify { expect(described_class.new(:foo)).not_to eq(described_class.new(:bar)) }

    context do
      let(:other_value) { Class.new(Chewy::Search::Parameters::Value) }
      specify { expect(other_value.new(:foo)).not_to eq(described_class.new(:foo)) }
      specify { expect(other_value.new(:foo)).to eq(other_value.new(:foo)) }
    end
  end

  describe '#replace' do
    specify { expect { subject.replace(42) }.to change { subject.value }.from(nil).to(42) }
    specify { expect { subject.replace('42') }.to change { subject.value }.from(nil).to('42') }
  end

  describe '#update' do
    specify { expect { subject.update(true) }.to change { subject.value }.from(nil).to(true) }
    specify { expect { subject.update(:symbol) }.to change { subject.value }.from(nil).to(:symbol) }
  end

  describe '#merge' do
    let(:other) { described_class.new(['something']) }
    specify { expect { subject.merge(other) }.to change { subject.value }.from(nil).to(['something']) }
  end
end

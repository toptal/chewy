require 'spec_helper'

describe Chewy::Search::Parameters::Limit do
  subject { described_class.new }

  describe '#initialize' do
    specify { expect(subject.value).to be_nil }
    specify { expect(described_class.new('42').value).to eq(42) }
    specify { expect(described_class.new(33.3).value).to eq(33) }
    specify { expect(described_class.new(nil).value).to eq(nil) }
  end

  describe '#replace' do
    specify { expect { subject.replace(42) }.to change { subject.value }.from(nil).to(42) }
  end

  describe '#update' do
    specify { expect { subject.update('42') }.to change { subject.value }.from(nil).to(42) }
  end

  describe '#merge' do
    specify { expect { subject.merge(described_class.new('33')) }.to change { subject.value }.from(nil).to(33) }
    specify { expect { subject.merge(described_class.new) }.not_to change { subject.value } }
  end

  describe '#render' do
    specify { expect(subject.render).to eq(nil) }
    specify { expect(described_class.new('42').render).to eq(size: 42) }
  end
end

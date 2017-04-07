require 'spec_helper'

shared_examples :bool do |param_name|
  subject { described_class.new(true) }

  describe '.param_name' do
    specify { expect(described_class.param_name).to eq(param_name) }
  end

  describe '#initialize' do
    specify { expect(subject.value).to eq(true) }
    specify { expect(described_class.new.value).to eq(false) }
    specify { expect(described_class.new(42).value).to eq(true) }
    specify { expect(described_class.new(nil).value).to eq(false) }
  end

  describe '#replace' do
    specify { expect { subject.replace(false) }.to change { subject.value }.from(true).to(false) }
    specify { expect { subject.replace(nil) }.to change { subject.value }.from(true).to(false) }
  end

  describe '#update' do
    specify { expect { subject.update(false) }.to change { subject.value }.from(true).to(false) }
    specify { expect { subject.update(nil) }.to change { subject.value }.from(true).to(false) }
  end

  describe '#merge' do
    specify { expect { subject.merge(described_class.new(false)) }.to change { subject.value }.from(true).to(false) }
    specify { expect { subject.merge(described_class.new) }.to change { subject.value }.from(true).to(false) }
  end

  describe '#render' do
    specify { expect(described_class.new.render).to eq(nil) }
    specify { expect(subject.render).to eq(param_name => true) }
  end
end

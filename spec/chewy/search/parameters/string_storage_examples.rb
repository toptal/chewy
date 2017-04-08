require 'spec_helper'

shared_examples :string_storage do |param_name|
  subject { described_class.new(:foo) }

  describe '#initialize' do
    specify { expect(subject.value).to eq('foo') }
    specify { expect(described_class.new(42).value).to eq('42') }
    specify { expect(described_class.new('').value).to eq(nil) }
  end

  describe '#replace' do
    specify { expect { subject.replace('bar') }.to change { subject.value }.from('foo').to('bar') }
    specify { expect { subject.replace('') }.to change { subject.value }.from('foo').to(nil) }
  end

  describe '#update' do
    specify { expect { subject.update('bar') }.to change { subject.value }.from('foo').to('bar') }
    specify { expect { subject.update('') }.to change { subject.value }.from('foo').to(nil) }
  end

  describe '#merge' do
    specify { expect { subject.merge(described_class.new('bar')) }.to change { subject.value }.from('foo').to('bar') }
    specify { expect { subject.merge(described_class.new) }.to change { subject.value }.from('foo').to(nil) }
  end

  describe '#render' do
    specify { expect(described_class.new.render).to eq(nil) }
    specify { expect(subject.render).to eq(param_name => 'foo') }
  end
end

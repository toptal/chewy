require 'spec_helper'

describe Chewy::Strategy::Base do
  subject { described_class.new }

  describe '#name' do
    specify { expect(subject.name).to eq(:base) }
  end

  describe '#update' do
    specify do
      expect { subject.update('SomeIndex', [1, 2]) }
        .to raise_error(Chewy::UndefinedUpdateStrategy)
    end
  end

  describe '#leave' do
    specify { expect(subject.leave).to be_nil }
  end

  describe '#update_chewy_indices' do
    let(:object) { double(run_chewy_callbacks: true) }

    specify do
      expect(object).to receive(:run_chewy_callbacks)
      subject.update_chewy_indices(object)
    end
  end
end

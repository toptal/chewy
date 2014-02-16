require 'spec_helper'

describe Chewy::Repository do
  include ClassHelpers

  subject { described_class.new(:analyzer) }

  describe '.resolve' do
    it 'calls #set with options' do
      expect(subject).to receive(:set).with(:analyzer, option: :foo)
      subject.resolve(:analyzer, option: :foo)
    end
    it 'calls #get with no options' do
      expect(subject).to receive(:get).with(:analyzer)
      subject.resolve(:analyzer)
    end
  end

  describe '.set' do
    specify { expect { subject.set(:analyzer, option: :foo) }.to_not raise_error }
  end

  describe '.get' do
    it 'raises error when analyzer is undefined' do
      expect { subject.get(:undefined_analyzer) }.to raise_error Chewy::UndefinedAnalysisUnit, 'Undefined analyzer: :undefined_analyzer'
    end

    it 'returns defined analizer' do
      subject.set(:analyzer, option: :foo)
      subject.get(:analyzer).should == {analyzer: {option: :foo}}
    end
  end
end

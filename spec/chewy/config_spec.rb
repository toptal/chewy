require 'spec_helper'

describe Chewy::Config do
  subject { described_class.send(:new) }

  its(:query_mode) { should == :must }
  its(:filter_mode) { should == :and }
  its(:post_filter_mode) { should be_nil }
  its(:logger) { should be_nil }
  its(:configuration) { should_not have_key :logger }
  its(:analyzers) { should == {} }
  its(:tokenizers) { should == {} }
  its(:filters) { should == {} }
  its(:char_filters) { should == {} }

  describe '#analyzer' do
    specify { expect(subject.analyzer(:name)).to be_nil }

    context do
      before { subject.analyzer(:name, option: :foo) }
      specify { expect(subject.analyzer(:name)).to eq({option: :foo}) }
      specify { expect(subject.analyzers).to eq({name: {option: :foo}}) }
    end
  end

  describe '#tokenizer' do
    specify { expect(subject.tokenizer(:name)).to be_nil }

    context do
      before { subject.tokenizer(:name, option: :foo) }
      specify { expect(subject.tokenizer(:name)).to eq({option: :foo}) }
      specify { expect(subject.tokenizers).to eq({name: {option: :foo}}) }
    end
  end

  describe '#filter' do
    specify { expect(subject.filter(:name)).to be_nil }

    context do
      before { subject.filter(:name, option: :foo) }
      specify { expect(subject.filter(:name)).to eq({option: :foo}) }
      specify { expect(subject.filters).to eq({name: {option: :foo}}) }
    end
  end

  describe '#char_filter' do
    specify { expect(subject.char_filter(:name)).to be_nil }

    context do
      before { subject.char_filter(:name, option: :foo) }
      specify { expect(subject.char_filter(:name)).to eq({option: :foo}) }
      specify { expect(subject.char_filters).to eq({name: {option: :foo}}) }
    end
  end

  describe '#logger' do
    before { subject.logger = double(:logger) }

    its(:logger) { should_not be_nil }
    its(:configuration) { should have_key :logger }
  end

  describe '#urgent_update=' do
    specify do
      subject.urgent_update = true
      expect(subject.strategy.current).to be_a(Chewy::Strategy::Urgent)
      subject.urgent_update = false
      expect(subject.strategy.current).to be_a(Chewy::Strategy::Base)
    end
  end

  describe '#atomic' do
    specify do
      subject.atomic { expect(subject.strategy.current).to be_a(Chewy::Strategy::Atomic) }
    end
  end
end

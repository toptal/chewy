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

  describe '#atomic?' do
    its(:atomic?) { should eq(false) }
    specify { subject.atomic { expect(subject.atomic?).to eq(true) } }
    specify { subject.atomic { }; expect(subject.atomic?).to eq(false) }
  end

  describe '#atomic' do
    before do
      stub_index(:dummies) do
        define_type :dummy
      end
    end
    let(:dummy_type) { DummiesIndex::Dummy }

    specify { expect(subject.atomic { 42 }).to eq(42) }
    specify { expect { subject.atomic { subject.stash Class.new, 42 } }.to raise_error ArgumentError }
    specify { subject.atomic { subject.atomic { expect(subject.stash).to eq([{}, {}]) } } }

    specify do
      expect(dummy_type).to receive(:import).with([1, 2, 3]).once
      subject.atomic do
        subject.stash dummy_type, [1, 2]
        subject.stash dummy_type, [2, 3]
      end
    end

    specify do
      expect(dummy_type).to receive(:import).with([1, 2]).once
      subject.atomic do
        subject.stash dummy_type, [1, 2]
        raise
      end rescue nil
    end

    specify do
      expect(dummy_type).to receive(:import).with([2, 3]).once
      expect(dummy_type).to receive(:import).with([1, 2]).once
      subject.atomic do
        subject.stash dummy_type, [2, 3]
        subject.atomic do
          subject.stash dummy_type, [1, 2]
        end
      end
    end
  end

  describe '#stash' do
    specify { subject.atomic { expect(subject.stash).to eq([{}]) } }
  end
end

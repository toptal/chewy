require 'spec_helper'

describe Chewy::Config do
  include ClassHelpers
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
    specify { subject.analyzer(:name).should be_nil }

    context do
      before { subject.analyzer(:name, option: :foo) }
      specify { subject.analyzer(:name).should == {option: :foo} }
      specify { subject.analyzers.should == {name: {option: :foo}} }
    end
  end

  describe '#tokenizer' do
    specify { subject.tokenizer(:name).should be_nil }

    context do
      before { subject.tokenizer(:name, option: :foo) }
      specify { subject.tokenizer(:name).should == {option: :foo} }
      specify { subject.tokenizers.should == {name: {option: :foo}} }
    end
  end

  describe '#filter' do
    specify { subject.filter(:name).should be_nil }

    context do
      before { subject.filter(:name, option: :foo) }
      specify { subject.filter(:name).should == {option: :foo} }
      specify { subject.filters.should == {name: {option: :foo}} }
    end
  end

  describe '#char_filter' do
    specify { subject.char_filter(:name).should be_nil }

    context do
      before { subject.char_filter(:name, option: :foo) }
      specify { subject.char_filter(:name).should == {option: :foo} }
      specify { subject.char_filters.should == {name: {option: :foo}} }
    end
  end

  describe '#logger' do
    before { subject.logger = double(:logger) }

    its(:logger) { should_not be_nil }
    its(:configuration) { should have_key :logger }
  end

  describe '#atomic?' do
    its(:atomic?) { should be_false }
    specify { subject.atomic { subject.atomic?.should be_true } }
    specify { subject.atomic { }; subject.atomic?.should be_false }
  end

  describe '#atomic' do
    before do
      stub_index(:dummies) do
        define_type :dummy
      end
    end
    let(:dummy_type) { DummiesIndex::Dummy }

    specify { subject.atomic { 42 }.should == 42 }
    specify { expect { subject.atomic { subject.stash Class.new, 42 } }.to raise_error ArgumentError }
    specify { subject.atomic { subject.atomic { subject.stash.should == [{}, {}] } } }

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
    specify { subject.atomic { subject.stash.should == [{}] } }
  end
end

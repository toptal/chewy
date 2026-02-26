require 'spec_helper'

describe Chewy::Repository do
  subject { described_class.send(:new) }

  specify { expect(subject.analyzers).to eq({}) }
  specify { expect(subject.tokenizers).to eq({}) }
  specify { expect(subject.filters).to eq({}) }
  specify { expect(subject.char_filters).to eq({}) }

  describe '#analyzer' do
    specify { expect(subject.analyzer(:name)).to be_nil }

    context do
      before { subject.analyzer(:name, option: :foo) }
      specify { expect(subject.analyzer(:name)).to eq(option: :foo) }
      specify { expect(subject.analyzers).to eq(name: {option: :foo}) }
    end
  end

  describe '#tokenizer' do
    specify { expect(subject.tokenizer(:name)).to be_nil }

    context do
      before { subject.tokenizer(:name, option: :foo) }
      specify { expect(subject.tokenizer(:name)).to eq(option: :foo) }
      specify { expect(subject.tokenizers).to eq(name: {option: :foo}) }
    end
  end

  describe '#filter' do
    specify { expect(subject.filter(:name)).to be_nil }

    context do
      before { subject.filter(:name, option: :foo) }
      specify { expect(subject.filter(:name)).to eq(option: :foo) }
      specify { expect(subject.filters).to eq(name: {option: :foo}) }
    end
  end

  describe '#char_filter' do
    specify { expect(subject.char_filter(:name)).to be_nil }

    context do
      before { subject.char_filter(:name, option: :foo) }
      specify { expect(subject.char_filter(:name)).to eq(option: :foo) }
      specify { expect(subject.char_filters).to eq(name: {option: :foo}) }
    end
  end
end

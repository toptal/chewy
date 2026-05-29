require 'spec_helper'
require 'chewy/index/import/progressbar'

describe Chewy::Index::Import::Progressbar do
  before do
    allow(ProgressBar).to receive(:create).and_wrap_original do |m, **opts|
      m.call(**opts, output: StringIO.new)
    end
  end

  describe '.build' do
    it 'returns the NULL object when disabled' do
      progressbar = described_class.build(false, 100)
      expect(progressbar).to be(described_class::NULL)
    end

    it 'returns a real bar when enabled with a total' do
      progressbar = described_class.build(true, 50)
      expect(progressbar).to be_a(described_class)
      expect(progressbar.bar.total).to eq(50)
    end

    it 'returns a spinner bar with nil total when :unbounded' do
      progressbar = described_class.build(:unbounded, 999)
      expect(progressbar).to be_a(described_class)
      expect(progressbar.bar.total).to be_nil
    end

    it 'bounded format includes percentage' do
      expect(described_class::BOUNDED_FORMAT).to include('%p')
    end

    it 'unbounded format omits percentage, total, and ETA' do
      expect(described_class::UNBOUNDED_FORMAT).not_to include('%p')
      expect(described_class::UNBOUNDED_FORMAT).not_to include('%C')
      expect(described_class::UNBOUNDED_FORMAT).not_to include('%e')
    end
  end

  describe 'NULL object' do
    it 'is callable like a real bar without effect' do
      null = described_class::NULL
      expect { null.increment(10) }.not_to raise_error
      expect { null.total = 5 }.not_to raise_error
      expect { null.finish }.not_to raise_error
    end
  end

  describe '#increment' do
    it 'advances the underlying bar' do
      progressbar = described_class.new(10)
      progressbar.increment(3)
      expect(progressbar.bar.progress).to eq(3)
    end

    it 'clamps to total when overshooting' do
      progressbar = described_class.new(5)
      progressbar.increment(10)
      expect(progressbar.bar.progress).to eq(5)
    end

    it 'is unbounded when total is nil' do
      progressbar = described_class.new(nil)
      progressbar.increment(1_000_000)
      expect(progressbar.bar.progress).to eq(1_000_000)
    end
  end

  describe '.normalize_total' do
    it 'sums Hash values (e.g., grouped AR count)' do
      expect(described_class.normalize_total({a: 3, b: 7})).to eq(10)
    end

    it 'returns Integer untouched' do
      expect(described_class.normalize_total(42)).to eq(42)
    end

    it 'returns nil for anything else' do
      expect(described_class.normalize_total('weird')).to be_nil
    end
  end

  describe '#finish' do
    it 'is idempotent' do
      progressbar = described_class.new(1)
      progressbar.increment(1)
      expect { 2.times { progressbar.finish } }.not_to raise_error
      expect(progressbar.bar).to be_finished
    end
  end
end

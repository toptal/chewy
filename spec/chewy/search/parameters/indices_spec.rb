require 'spec_helper'

describe Chewy::Search::Parameters::Indices do
  before do
    stub_index(:first)
    stub_index(:second)
    stub_index(:third)
  end

  subject { described_class.new(indices: [FirstIndex, SecondIndex]) }

  describe '#initialize' do
    specify { expect(described_class.new.value).to eq(indices: []) }
    specify { expect(described_class.new(nil).value).to eq(indices: []) }
    specify { expect(described_class.new(foo: :whatever).value).to eq(indices: []) }
    specify { expect(subject.value).to eq(indices: [FirstIndex, SecondIndex]) }
  end

  describe '#replace!' do
    specify do
      expect { subject.replace!(nil) }
        .to change { subject.value }
        .from(indices: [FirstIndex, SecondIndex])
        .to(indices: [])
    end

    specify do
      expect { subject.replace!(indices: SecondIndex) }
        .to change { subject.value }
        .from(indices: [FirstIndex, SecondIndex])
        .to(indices: [SecondIndex])
    end
  end

  describe '#update!' do
    specify do
      expect { subject.update!(nil) }
        .not_to change { subject.value }
    end

    specify do
      expect { subject.update!(indices: ThirdIndex) }
        .to change { subject.value }
        .from(indices: [FirstIndex, SecondIndex])
        .to(indices: [FirstIndex, SecondIndex, ThirdIndex])
    end
  end

  describe '#merge!' do
    specify do
      expect { subject.merge!(described_class.new) }
        .not_to change { subject.value }
    end

    specify do
      expect { subject.merge!(described_class.new(indices: SecondIndex)) }
        .not_to change { subject.value }
    end
  end

  describe '#render' do
    specify { expect(described_class.new.render).to eq({}) }
    specify do
      expect(described_class.new(
        indices: FirstIndex
      ).render).to eq(index: %w[first])
    end
    specify do
      expect(described_class.new(
        indices: :whatever
      ).render).to eq(index: %w[whatever])
    end
    specify do
      expect(described_class.new(
        indices: [FirstIndex, :whatever]
      ).render).to eq(index: %w[first whatever])
    end
  end

  describe '#==' do
    specify { expect(described_class.new).to eq(described_class.new) }
    specify do
      expect(described_class.new(indices: :first))
        .to eq(described_class.new(indices: FirstIndex))
    end
    specify do
      expect(described_class.new(indices: FirstIndex))
        .to eq(described_class.new(indices: FirstIndex))
    end
  end

  describe '#indices' do
    specify do
      expect(described_class.new(
        indices: [FirstIndex, :whatever]
      ).indices).to contain_exactly(FirstIndex)
    end
  end
end

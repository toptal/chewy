require 'spec_helper'

describe Chewy::Search::Parameters::Indices do
  before do
    stub_index(:first) do
      define_type :one
      define_type :two
    end

    stub_index(:second) do
      define_type :three
    end
  end

  subject { described_class.new(indices: FirstIndex, types: SecondIndex::Three) }

  describe '#initialize' do
    specify { expect(described_class.new.value).to eq(indices: [], types: []) }
    specify { expect(described_class.new(nil).value).to eq(indices: [], types: []) }
    specify { expect(described_class.new(foo: :whatever).value).to eq(indices: [], types: []) }
    specify { expect(subject.value).to eq(indices: [FirstIndex], types: [SecondIndex::Three]) }
  end

  describe '#replace!' do
    specify do
      expect { subject.replace!(nil) }
        .to change { subject.value }
        .from(indices: [FirstIndex], types: [SecondIndex::Three])
        .to(indices: [], types: [])
    end

    specify do
      expect { subject.replace!(indices: SecondIndex, types: FirstIndex::One) }
        .to change { subject.value }
        .from(indices: [FirstIndex], types: [SecondIndex::Three])
        .to(indices: [SecondIndex], types: [FirstIndex::One])
    end
  end

  describe '#update!' do
    specify do
      expect { subject.update!(nil) }
        .not_to change { subject.value }
    end

    specify do
      expect { subject.update!(indices: SecondIndex, types: [FirstIndex::One, SecondIndex::Three]) }
        .to change { subject.value }
        .from(indices: [FirstIndex], types: [SecondIndex::Three])
        .to(indices: [FirstIndex, SecondIndex], types: [SecondIndex::Three, FirstIndex::One])
    end
  end

  describe '#merge!' do
    specify do
      expect { subject.merge!(described_class.new) }
        .not_to change { subject.value }
    end

    specify do
      expect { subject.merge!(described_class.new(indices: SecondIndex, types: [FirstIndex::One, SecondIndex::Three])) }
        .to change { subject.value }
        .from(indices: [FirstIndex], types: [SecondIndex::Three])
        .to(indices: [FirstIndex, SecondIndex], types: [SecondIndex::Three, FirstIndex::One])
    end
  end

  describe '#render' do
    specify { expect(described_class.new.render).to eq({}) }
    specify do
      expect(described_class.new(
        indices: FirstIndex
      ).render).to eq(index: %w[first], type: %w[one two])
    end
    specify do
      expect(described_class.new(
        indices: :whatever
      ).render).to eq(index: %w[whatever])
    end
    specify do
      expect(described_class.new(
        types: FirstIndex::One
      ).render).to eq(index: %w[first], type: %w[one])
    end
    specify do
      expect(described_class.new(
        types: :whatever
      ).render).to eq({})
    end
    specify do
      expect(described_class.new(
        indices: FirstIndex, types: SecondIndex::Three
      ).render).to eq(index: %w[first second], type: %w[one three two])
    end
    specify do
      expect(described_class.new(
        indices: FirstIndex, types: :one
      ).render).to eq(index: %w[first], type: %w[one])
    end
    specify do
      expect(described_class.new(
        indices: FirstIndex, types: :whatever
      ).render).to eq(index: %w[first], type: %w[one two])
    end
    specify do
      expect(described_class.new(
        indices: FirstIndex, types: %i[one whatever]
      ).render).to eq(index: %w[first], type: %w[one])
    end
    specify do
      expect(described_class.new(
        indices: :whatever, types: SecondIndex::Three
      ).render).to eq(index: %w[second whatever], type: %w[three])
    end
    specify do
      expect(described_class.new(
        indices: :whatever, types: [SecondIndex::Three, :whatever]
      ).render).to eq(index: %w[second whatever], type: %w[three whatever])
    end
    specify do
      expect(described_class.new(
        indices: [FirstIndex, :whatever], types: FirstIndex::One
      ).render).to eq(index: %w[first whatever], type: %w[one])
    end
    specify do
      expect(described_class.new(
        indices: FirstIndex, types: [FirstIndex::One, :whatever]
      ).render).to eq(index: %w[first], type: %w[one])
    end
    specify do
      expect(described_class.new(
        indices: FirstIndex, types: [SecondIndex::Three, :whatever]
      ).render).to eq(index: %w[first second], type: %w[one three two])
    end
    specify do
      expect(described_class.new(
        indices: [FirstIndex, :whatever], types: [FirstIndex::One, :whatever]
      ).render).to eq(index: %w[first whatever], type: %w[one whatever])
    end
    specify do
      expect(described_class.new(
        indices: [FirstIndex, :whatever], types: [SecondIndex::Three, FirstIndex::One]
      ).render).to eq(index: %w[first second whatever], type: %w[one three])
    end
  end

  describe '#==' do
    specify { expect(described_class.new).to eq(described_class.new) }
    specify do
      expect(described_class.new(indices: SecondIndex, types: [SecondIndex::Three, :whatever]))
        .to eq(described_class.new(indices: SecondIndex, types: :whatever))
    end
    specify do
      expect(described_class.new(indices: :first, types: %w[one two]))
        .to eq(described_class.new(indices: FirstIndex))
    end
    specify do
      expect(described_class.new(indices: FirstIndex, types: SecondIndex::Three))
        .not_to eq(described_class.new(indices: FirstIndex))
    end
  end

  describe '#indices' do
    specify do
      expect(described_class.new(
        indices: [FirstIndex, :whatever],
        types: [SecondIndex::Three, :whatever]
      ).indices).to contain_exactly(FirstIndex, SecondIndex)
    end
  end

  describe '#types' do
    specify do
      expect(described_class.new(
        indices: [FirstIndex, :whatever],
        types: [SecondIndex::Three, :whatever]
      ).types).to contain_exactly(
        FirstIndex::One, FirstIndex::Two, SecondIndex::Three
      )
    end

    specify do
      expect(described_class.new(
        indices: [FirstIndex, :whatever],
        types: [FirstIndex::One, SecondIndex::Three, :whatever]
      ).types).to contain_exactly(
        FirstIndex::One, SecondIndex::Three
      )
    end
  end
end

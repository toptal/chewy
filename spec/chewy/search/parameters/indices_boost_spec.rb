require 'spec_helper'

describe Chewy::Search::Parameters::IndicesBoost do
  subject { described_class.new(cities: 1.2) }

  describe '#initialize' do
    specify { expect(described_class.new.value).to eq({}) }
    specify { expect(described_class.new(nil).value).to eq({}) }
    specify { expect(described_class.new(cities: 1.2).value).to eq('cities' => 1.2) }
    specify { expect(described_class.new(cities: '1.2').value).to eq('cities' => 1.2) }
    specify { expect(described_class.new(cities: 2).value).to eq('cities' => 2.0) }
  end

  describe '#update!' do
    specify do
      expect { subject.update!(countries: 0.5) }
        .to change { subject.value }
        .from('cities' => 1.2)
        .to('cities' => 1.2, 'countries' => 0.5)
    end

    specify do
      expect { subject.update!(cities: 2.0) }
        .to change { subject.value }
        .from('cities' => 1.2)
        .to('cities' => 2.0)
    end
  end

  describe '#merge!' do
    specify do
      expect { subject.merge!(described_class.new(countries: 0.5)) }
        .to change { subject.value }
        .from('cities' => 1.2)
        .to('cities' => 1.2, 'countries' => 0.5)
    end

    specify do
      expect { subject.merge!(described_class.new) }
        .not_to change { subject.value }
    end
  end

  describe '#render' do
    specify { expect(described_class.new.render).to be_nil }
    specify { expect(described_class.new(cities: 1.2).render).to eq(indices_boost: [{'cities' => 1.2}]) }
    specify do
      param = described_class.new(cities: 1.2)
      param.update!(countries: 0.5)
      expect(param.render).to eq(indices_boost: [{'cities' => 1.2}, {'countries' => 0.5}])
    end
  end

  describe '#==' do
    specify { expect(described_class.new(cities: 1.2)).to eq(described_class.new(cities: 1.2)) }
    specify { expect(described_class.new(cities: 1.2)).not_to eq(described_class.new(cities: 2.0)) }

    it 'considers key order' do
      a = described_class.new(cities: 1.2)
      a.update!(countries: 0.5)

      b = described_class.new(countries: 0.5)
      b.update!(cities: 1.2)

      expect(a).not_to eq(b)
    end
  end
end

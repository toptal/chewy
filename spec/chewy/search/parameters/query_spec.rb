require 'spec_helper'

describe Chewy::Search::Parameters::Query do
  subject { described_class.new(match: { foo: 'bar' }) }

  describe '#initialize' do
    specify { expect(described_class.new.value).to eq({}) }
    specify { expect(described_class.new(nil).value).to eq({}) }
    specify { expect(subject.value).to eq(match: { foo: 'bar' }) }
    specify { expect(described_class.new(proc { match foo: 'bar' }).value).to eq(match: { foo: 'bar' }) }
  end

  describe '#replace' do
    specify do
      expect { subject.replace(proc { multi_match foo: 'bar' }) }
        .to change { subject.value }
        .from(match: { foo: 'bar' }).to(multi_match: { foo: 'bar' })
    end

    specify do
      expect { subject.replace(nil) }
        .to change { subject.value }
        .from(match: { foo: 'bar' }).to({})
    end
  end

  describe '#update' do
    specify do
      expect { subject.update(proc { multi_match foo: 'bar' }) }
        .to change { subject.value }
        .from(match: { foo: 'bar' }).to(multi_match: { foo: 'bar' })
    end

    specify do
      expect { subject.update(nil) }
        .to change { subject.value }
        .from(match: { foo: 'bar' }).to({})
    end
  end

  describe '#merge' do
    specify do
      expect { subject.merge(described_class.new(multi_match: { foo: 'bar' })) }
        .to change { subject.value }
        .from(match: { foo: 'bar' }).to(multi_match: { foo: 'bar' })
    end

    specify do
      expect { subject.merge(described_class.new) }
        .to change { subject.value }
        .from(match: { foo: 'bar' }).to({})
    end
  end

  describe '#render' do
    specify { expect(described_class.new.render).to be_nil }
    specify { expect(subject.render).to eq(query: { match: { foo: 'bar' } }) }
  end
end

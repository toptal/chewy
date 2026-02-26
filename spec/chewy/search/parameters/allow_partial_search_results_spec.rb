require 'spec_helper'

describe Chewy::Search::Parameters::AllowPartialSearchResults do
  subject { described_class.new(true) }

  describe '#initialize' do
    specify { expect(described_class.new.value).to be_nil }
    specify { expect(described_class.new(nil).value).to be_nil }
    specify { expect(described_class.new(true).value).to be true }
    specify { expect(described_class.new(false).value).to be false }
  end

  describe '#replace!' do
    specify { expect { subject.replace!(false) }.to change { subject.value }.from(true).to(false) }
    specify { expect { subject.replace!(nil) }.to change { subject.value }.from(true).to(nil) }
  end

  describe '#update!' do
    specify { expect { subject.update!(false) }.to change { subject.value }.from(true).to(false) }
    specify { expect { subject.update!(nil) }.not_to change { subject.value }.from(true) }
  end

  describe '#merge!' do
    specify { expect { subject.merge!(described_class.new(false)) }.to change { subject.value }.from(true).to(false) }
    specify { expect { subject.merge!(described_class.new) }.not_to change { subject.value }.from(true) }
  end

  describe '#render' do
    specify { expect(described_class.new.render).to be_nil }
    specify { expect(described_class.new(true).render).to eq(allow_partial_search_results: true) }
    specify { expect(described_class.new(false).render).to eq(allow_partial_search_results: false) }
  end
end

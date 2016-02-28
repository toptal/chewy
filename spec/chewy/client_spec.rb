require 'spec_helper'

describe Chewy::Client do
  subject { described_class.create(Chewy.clients[:default]) }

  describe '.create' do
    specify { expect(subject).to be_a(Chewy::Client) }
  end

  describe '#version' do
    specify { expect(subject.version).to be_a(Chewy::Client::Version) }
    specify { expect(subject.version).to be >= '2.4' }
    specify { expect(subject.version).to be < '6.0' }
  end
end

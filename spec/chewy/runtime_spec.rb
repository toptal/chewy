require 'spec_helper'

describe Chewy::Runtime do
  describe '.version' do
    specify { expect(described_class.version).to be_a(described_class::Version) }
    specify { expect(described_class.version).to be >= '5.6' }
    specify { expect(described_class.version).to be < '7.0' }
  end
end

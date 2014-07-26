require 'spec_helper'

describe Chewy::Runtime do
  describe '.version' do
    specify { described_class.version.should be_a(described_class::Version) }
    specify { described_class.version.should be >= '1.0' }
    specify { described_class.version.should be == '1.3' }
  end
end

require 'spec_helper'

describe Chewy::Runtime::Version do
  describe '#major' do
    specify { described_class.new('1.2.3').major.should == 1 }
    specify { described_class.new('1.2').major.should == 1 }
    specify { described_class.new(1.2).major.should == 1 }
    specify { described_class.new('1').major.should == 1 }
    specify { described_class.new('').major.should == 0 }
  end

  describe '#minor' do
    specify { described_class.new('1.2.3').minor.should == 2 }
    specify { described_class.new('1.2').minor.should == 2 }
    specify { described_class.new(1.2).minor.should == 2 }
    specify { described_class.new('1').minor.should == 0 }
  end

  describe '#patch' do
    specify { described_class.new('1.2.3').patch.should == 3 }
    specify { described_class.new('1.2.3.pre1').patch.should == 3 }
    specify { described_class.new('1.2').patch.should == 0 }
    specify { described_class.new(1.2).patch.should == 0 }
  end

  describe '#to_s' do
    specify { described_class.new('1.2.3').to_s.should == '1.2.3' }
    specify { described_class.new('1.2.3.pre1').to_s.should == '1.2.3' }
    specify { described_class.new('1.2').to_s.should == '1.2.0' }
    specify { described_class.new(1.2).to_s.should == '1.2.0' }
    specify { described_class.new('1').to_s.should == '1.0.0' }
    specify { described_class.new('').to_s.should == '0.0.0' }
  end

  describe '#<=>' do
    specify { described_class.new('1.2.3').should == '1.2.3' }
    specify { described_class.new('1.2.3').should be < '1.2.4' }
    specify { described_class.new('1.2.3').should be < '1.2.10' }
    specify { described_class.new('1.10.2').should be == '1.10.2' }
    specify { described_class.new('1.10.2').should be > '1.7.2' }
    specify { described_class.new('2.10.2').should be > '1.7.2' }
    specify { described_class.new('1.10.2').should be < '2.7.2' }
    specify { described_class.new('1.10.2').should be < described_class.new('2.7.2') }
    specify { described_class.new('1.10.2').should be < 2.7 }
    specify { described_class.new('1.10.2').should be < 1.11 }
    specify { described_class.new('1.2.0').should be == '1.2' }
  end
end

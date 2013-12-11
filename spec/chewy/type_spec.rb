require 'spec_helper'

describe Chewy::Type do
  include ClassHelpers

  describe '.new' do
    before do
      stub_index(:cities)
    end

    context 'Symbol' do
      subject { described_class.new(CitiesIndex, :city) }

      it { should be_a Class }
      it { should be < Chewy::Type::Base }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'ActiveRecord model' do
      before { stub_model(:city) }
      subject { described_class.new(CitiesIndex, City) }

      it { should be_a Class }
      it { should be < Chewy::Type::Base }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'ActiveRecord scope' do
      before { stub_model(:city) }
      subject { described_class.new(CitiesIndex, City.includes(:country)) }

      it { should be_a Class }
      it { should be < Chewy::Type::Base }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end
  end
end

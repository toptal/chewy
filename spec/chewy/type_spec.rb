require 'spec_helper'

describe Chewy::Type do
  describe '.new' do
    before { stub_index(:cities) }

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

    context 'Namespaced index' do
      before { stub_model(:city) }
      before { stub_index('namespace/cities') }

      subject { described_class.new(Namespace::CitiesIndex, City) }

      it { should be_a Class }
      it { should be < Chewy::Type::Base }
      its(:name) { should == 'Namespace::CitiesIndex::City' }
      its(:index) { should == Namespace::CitiesIndex }
      its(:type_name) { should == 'city' }
    end

    context 'Namespaced model' do
      before { stub_model('namespace/city') }

      subject { described_class.new(CitiesIndex, Namespace::City) }

      it { should be_a Class }
      it { should be < Chewy::Type::Base }
      its(:name) { should == 'CitiesIndex::City' }
      its(:index) { should == CitiesIndex }
      its(:type_name) { should == 'city' }
    end
  end
end

require 'spec_helper'

describe Chewy::Type::Adapter::Sequel, :sequel do

  let(:adapter) { described_class }

  before do
    stub_model(:city)
    stub_model(:country)
  end

  describe '#name' do

    it { expect( adapter.new(City).name ).to eq 'City' }
    it { expect( adapter.new(City.order(:id)).name ).to eq 'City' }
    it { expect( adapter.new(City, name: 'town').name ).to eq 'Town' }

    context do
      before { stub_model('namespace/city') }

      it { expect( adapter.new(Namespace::City).name ).to eq 'City' }
      it { expect( adapter.new(Namespace::City.order(:id)).name ).to eq 'City' }
    end
  end

  describe '#default_dataset' do

    it { expect( adapter.new(City).default_dataset.sql ).to eql City.where(nil).sql }
    it { expect( adapter.new(City.order(:id)).default_dataset.sql ).to eql City.where(nil).sql }
    it { expect( adapter.new(City.limit(10)).default_dataset.sql ).to eql City.where(nil).sql  }
    it { expect( adapter.new(City.offset(10)).default_dataset.sql ).to eql City.where(nil).sql }
    it { expect( adapter.new(City.where(rating: 10)).default_dataset.sql ).to eql City.where(rating: 10).sql }
  end

  describe '#identify' do
    context do
      subject(:s) { adapter.new(City) }
      let!(:cities) { 3.times.map { City.new.save } }

      it { expect( s.identify(City.where(nil)) ).to match_array cities.map(&:id) }
      it { expect( s.identify(cities) ).to eq cities.map(&:id) }
      it { expect( s.identify(cities.first) ).to eq([cities.first.id]) }
      it { expect( s.identify(cities.first(2).map(&:pk)) ).to eq cities.first(2).map(&:id) }
    end
  end
end

require 'spec_helper'

describe Chewy::Type::Adapter::ActiveRecord do
  before { stub_model(:city) }

  describe '#name' do
    specify { described_class.new(City).name.should == 'City' }
    specify { described_class.new(City.order(:id)).name.should == 'City' }
    specify { described_class.new(City, name: 'town').name.should == 'Town' }
  end

  describe '#type_name' do
    specify { described_class.new(City).type_name.should == 'city' }
    specify { described_class.new(City.order(:id)).type_name.should == 'city' }
    specify { described_class.new(City, name: 'town').type_name.should == 'town' }
  end

  describe '#import' do
    def import(*args)
      result = []
      subject.import(*args) { |data| result.push data }
      result
    end

    specify { subject.import(3.times.map { |i| City.create! }) { |data| true }.should be_true }
    specify { subject.import(3.times.map { |i| City.create! }) { |data| false }.should be_false }

    context do
      let!(:cities) { 3.times.map { |i| City.create! } }
      let!(:deleted) { 3.times.map { |i| City.create!.tap(&:destroy!) } }
      subject { described_class.new(City) }

      specify { import.should == [{index: cities}] }

      specify { import(City.order(:id)).should == [{index: cities}] }
      specify { import(City.order(:id), batch_size: 2)
        .should == [{index: cities.first(2)}, {index: cities.last(1)}] }

      specify { import(cities).should == [{index: cities}] }
      specify { import(cities, batch_size: 2)
          .should == [{index: cities.first(2)}, {index: cities.last(1)}] }
      specify { import(cities, deleted).should == [{index: cities, delete: deleted}] }
      specify { import(cities, deleted, batch_size: 2).should == [
          {index: cities.first(2)},
          {index: cities.last(1), delete: deleted.first(1)},
          {delete: deleted.last(2)}] }

      specify { import(cities.map(&:id)).should == [{index: cities}] }
      specify { import(cities.map(&:id), batch_size: 2)
        .should == [{index: cities.first(2)}, {index: cities.last(1)}] }
      specify { import(cities.map(&:id), deleted.map(&:id))
        .should == [{index: cities}, {delete: deleted.map(&:id)}] }
      specify { import(cities.map(&:id), deleted.map(&:id), batch_size: 2).should == [
        {index: cities.first(2)},
        {index: cities.last(1)},
        {delete: deleted.first(2).map(&:id)},
        {delete: deleted.last(1).map(&:id)}] }
    end

    context do
      let!(:cities) { 3.times.map { |i| City.create!(country_id: i/2) } }
      let!(:deleted) { 2.times.map { |i| City.create!.tap(&:destroy!) } }
      subject { described_class.new(City.where(country_id: 0)) }

      specify { import.should == [{index: cities.first(2)}] }

      specify { import(City.order(:id)).should == [{index: cities.first(2)}] }
      specify { import(City.order(:id), batch_size: 1)
        .should == [{index: [cities.first]}, {index: [cities.second]}] }

      specify { import(cities).should == [{index: cities}] }
      specify { import(cities, batch_size: 2)
        .should == [{index: cities.first(2)}, {index: cities.last(1)}] }

      specify { import(cities.map(&:id))
        .should == [{index: cities.first(2)}, {delete: [cities.last.id]}] }
      specify { import(cities.map(&:id), batch_size: 1)
        .should == [{index: [cities.first]}, {index: [cities.second]}, {delete: [cities.last.id]}] }
      specify { import(cities.map(&:id), deleted.map(&:id))
        .should == [{index: cities.first(2)}, {delete: [cities.last.id] + deleted.map(&:id)}] }
      specify { import(cities.map(&:id), deleted.map(&:id), batch_size: 2).should == [
        {index: cities.first(2)},
        {delete: [cities.last.id] + deleted.first(1).map(&:id)},
        {delete: deleted.last(1).map(&:id)}] }
    end
  end

  describe '#load' do
    let!(:cities) { 3.times.map { |i| City.create!(country_id: i/2) } }
    let!(:deleted) { 2.times.map { |i| City.create!.tap(&:destroy!) } }

    let(:type) { double(type_name: 'user') }

    subject { described_class.new(City) }

    specify { subject.load(cities.map { |c| double(id: c.id) }, _type: type).should == cities }
    specify { subject.load(cities.map { |c| double(id: c.id) }.reverse, _type: type).should == cities.reverse }
    specify { subject.load(deleted.map { |c| double(id: c.id) }, _type: type).should == [nil, nil] }
    specify { subject.load((cities + deleted).map { |c| double(id: c.id) }, _type: type).should == [*cities, nil, nil] }
    specify { subject.load(cities.map { |c| double(id: c.id) }, _type: type, scope: ->{ where(country_id: 0) })
      .should == cities.first(2) + [nil] }
    specify { subject.load(cities.map { |c| double(id: c.id) },
      _type: type, scope: ->{ where(country_id: 0) }, user: {scope: ->{ where(country_id: 1)}})
      .should == [nil, nil] + cities.last(1) }
    specify { subject.load(cities.map { |c| double(id: c.id) }, _type: type, scope: City.where(country_id: 1))
      .should == [nil, nil] + cities.last(1) }
    specify { subject.load(cities.map { |c| double(id: c.id) },
      _type: type, scope: City.where(country_id: 1), user: {scope: ->{ where(country_id: 0)}})
      .should == cities.first(2) + [nil] }
  end
end

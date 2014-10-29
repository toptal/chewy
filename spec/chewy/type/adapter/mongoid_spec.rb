require 'spec_helper'

describe Chewy::Type::Adapter::Mongoid, :mongoid do
  before { stub_model(:city) }

  describe '#name' do
    specify { described_class.new(City).name.should == 'City' }
    specify { described_class.new(City.order(:id.asc)).name.should == 'City' }
    specify { described_class.new(City, name: 'town').name.should == 'Town' }

    context do
      before { stub_model('namespace/city') }

      specify { described_class.new(Namespace::City).name.should == 'City' }
      specify { described_class.new(Namespace::City.order(:id.asc)).name.should == 'City' }
    end
  end

  describe '#type_name' do
    specify { described_class.new(City).type_name.should == 'city' }
    specify { described_class.new(City.order(:id.asc)).type_name.should == 'city' }
    specify { described_class.new(City, name: 'town').type_name.should == 'town' }

    context do
      before { stub_model('namespace/city') }

      specify { described_class.new(Namespace::City).type_name.should == 'city' }
      specify { described_class.new(Namespace::City.order(:id.asc)).type_name.should == 'city' }
    end
  end

  describe '#import' do
    def import(*args)
      result = []
      subject.import(*args) { |data| result.push data }
      result
    end

    context do
      let!(:cities) { 3.times.map { |i| City.create! }.sort_by(&:id) }
      let!(:deleted) { 3.times.map { |i| City.create!.tap(&:destroy) }.sort_by(&:id) }
      subject { described_class.new(City) }

      specify { import.should == [{index: cities}] }

      specify { import(City.order(:id.asc)).should == [{index: cities}] }
      specify { import(City.order(:id.asc), batch_size: 2)
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
      specify { import(deleted.map(&:id)).should == [{delete: deleted.map(&:id)}] }
      specify { import(cities.map(&:id), batch_size: 2)
        .should == [{index: cities.first(2)}, {index: cities.last(1)}] }
      specify { import(cities.map(&:id), deleted.map(&:id))
        .should == [{index: cities}, {delete: deleted.map(&:id)}] }
      specify { import(cities.map(&:id), deleted.map(&:id), batch_size: 2).should == [
        {index: cities.first(2)},
        {index: cities.last(1)},
        {delete: deleted.first(2).map(&:id)},
        {delete: deleted.last(1).map(&:id)}] }

      specify { import(cities.first, nil).should == [{index: [cities.first]}] }
      specify { import(cities.first.id, nil).should == [{index: [cities.first]}] }

      context do
        before { deleted.map { |object| object.stub(delete_from_index?: true, destroyed?: true) } }
        specify { import(deleted).should == [{delete: deleted}] }
      end

      context do
        before { deleted.map { |object| object.stub(delete_from_index?: true, destroyed?: false) } }
        specify { import(deleted).should == [{delete: deleted}] }
      end

      context do
        before { deleted.map { |object| object.stub(delete_from_index?: false, destroyed?: true) } }
        specify { import(deleted).should == [{delete: deleted}] }
      end

      context do
        before { deleted.map { |object| object.stub(delete_from_index?: false, destroyed?: false) } }
        specify { import(deleted).should == [{index: deleted}] }
      end
    end

    describe '#delete_from_index?' do
      before do
        stub_model(:city) do
          def delete_from_index?
            rating == 42
          end
        end
      end
      let!(:cities) { 3.times.map { |i| City.create! }.sort_by(&:id) }
      let!(:deleted) { 3.times.map { |i| City.create!(rating: 42) }.sort_by(&:id) }
      subject { described_class.new(City) }

      specify { import(cities, deleted).should == [{index: cities, delete: deleted}] }
      specify { import(cities.map(&:id), deleted.map(&:id))
        .should == [{index: cities, delete: deleted}] }
      specify { import(City.order(:id.asc)).should == [{index: cities, delete: deleted}] }
    end

    context 'default scope' do
      let!(:cities) { 3.times.map { |i| City.create!(rating: i/2) }.sort_by(&:id) }
      let!(:deleted) { 2.times.map { |i| City.create!.tap(&:destroy) }.sort_by(&:id) }
      subject { described_class.new(City.where(rating: 0)) }

      specify { import.should == [{index: cities.first(2)}] }

      specify { import(City.order(:id.asc)).should == [{index: cities.first(2)}] }
      xspecify { import(City.order(:id.asc), batch_size: 1)
        .should == [{index: [cities.first]}, {index: [cities.second]}] }

      specify { import(cities).should == [{index: cities}] }
      specify { import(cities, batch_size: 2)
        .should == [{index: cities.first(2)}, {index: cities.last(1)}] }

      specify { import(cities.map(&:id))
        .should == [{index: cities.first(2)}, {delete: [cities.last.id]}] }
      xspecify { import(cities.map(&:id), batch_size: 1)
        .should == [{index: [cities.first]}, {index: [cities.second]}, {delete: [cities.last.id]}] }
      specify { import(cities.map(&:id), deleted.map(&:id))
        .should == [{index: cities.first(2)}, {delete: [cities.last.id] + deleted.map(&:id)}] }
      specify { import(cities.map(&:id), deleted.map(&:id), batch_size: 2).should == [
        {index: cities.first(2)},
        {delete: [cities.last.id] + deleted.first(1).map(&:id)},
        {delete: deleted.last(1).map(&:id)}] }
    end

    context 'error handling' do
      let!(:cities) { 6.times.map { |i| City.create! }.sort_by(&:id) }
      let!(:deleted) { 4.times.map { |i| City.create!.tap(&:destroy) }.sort_by(&:id) }
      let(:ids) { (cities + deleted).map(&:id) }
      subject { described_class.new(City) }

      let(:data_comparer) do
        ->(ids, data) { objects = (data[:index] || data[:delete]).first(2); objects.map { |o| o.respond_to?(:id) ? o.id : o }.sort != ids.map(&:id).sort }
      end

      context 'implicit scope' do
        specify { subject.import { |data| true }.should eq(true) }
        specify { subject.import { |data| false }.should eq(false) }
        specify { subject.import(batch_size: 2, &data_comparer.curry[cities[0..1]]).should eq(false) }
        specify { subject.import(batch_size: 2, &data_comparer.curry[cities[2..3]]).should eq(false) }
        specify { subject.import(batch_size: 2, &data_comparer.curry[cities[4..5]]).should eq(false) }
        specify { subject.import(batch_size: 2, &data_comparer.curry[deleted[0..1]]).should eq(true) }
        specify { subject.import(batch_size: 2, &data_comparer.curry[deleted[2..3]]).should eq(true) }
      end

      context 'explicit scope' do
        let(:scope) { mongoid? ? City.where(:id.in => ids) : City.where(id: ids) }

        specify { subject.import(scope) { |data| true }.should eq(true) }
        specify { subject.import(scope) { |data| false }.should eq(false) }
        specify { subject.import(scope, batch_size: 2, &data_comparer.curry[cities[0..1]]).should eq(false) }
        specify { subject.import(scope, batch_size: 2, &data_comparer.curry[cities[2..3]]).should eq(false) }
        specify { subject.import(scope, batch_size: 2, &data_comparer.curry[cities[4..5]]).should eq(false) }
        specify { subject.import(scope, batch_size: 2, &data_comparer.curry[deleted[0..1]]).should eq(true) }
        specify { subject.import(scope, batch_size: 2, &data_comparer.curry[deleted[2..3]]).should eq(true) }
      end

      context 'objects' do
        specify { subject.import(cities + deleted) { |data| true }.should eq(true) }
        specify { subject.import(cities + deleted) { |data| false }.should eq(false) }
        specify { subject.import(cities + deleted, batch_size: 2, &data_comparer.curry[cities[0..1]]).should eq(false) }
        specify { subject.import(cities + deleted, batch_size: 2, &data_comparer.curry[cities[2..3]]).should eq(false) }
        specify { subject.import(cities + deleted, batch_size: 2, &data_comparer.curry[cities[4..5]]).should eq(false) }
        specify { subject.import(cities + deleted, batch_size: 2, &data_comparer.curry[deleted[0..1]]).should eq(false) }
        specify { subject.import(cities + deleted, batch_size: 2, &data_comparer.curry[deleted[2..3]]).should eq(false) }
      end

      context 'ids' do
        specify { subject.import(ids) { |data| true }.should eq(true) }
        specify { subject.import(ids) { |data| false }.should eq(false) }
        specify { subject.import(ids, batch_size: 2, &data_comparer.curry[cities[0..1]]).should eq(false) }
        specify { subject.import(ids, batch_size: 2, &data_comparer.curry[cities[2..3]]).should eq(false) }
        specify { subject.import(ids, batch_size: 2, &data_comparer.curry[cities[4..5]]).should eq(false) }
        specify { subject.import(ids, batch_size: 2, &data_comparer.curry[deleted[0..1]]).should eq(false) }
        specify { subject.import(ids, batch_size: 2, &data_comparer.curry[deleted[2..3]]).should eq(false) }
      end
    end
  end

  describe '#load' do
    context do
      let!(:cities) { 3.times.map { |i| City.create!(rating: i/2) }.sort_by(&:id) }
      let!(:deleted) { 2.times.map { |i| City.create!.tap(&:destroy) }.sort_by(&:id) }

      let(:type) { double(type_name: 'user') }

      subject { described_class.new(City) }

      specify { subject.load(cities.map { |c| double(id: c.id) }, _type: type).should == cities }
      specify { subject.load(cities.map { |c| double(id: c.id) }.reverse, _type: type).should == cities.reverse }
      specify { subject.load(deleted.map { |c| double(id: c.id) }, _type: type).should == [nil, nil] }
      specify { subject.load((cities + deleted).map { |c| double(id: c.id) }, _type: type).should == [*cities, nil, nil] }
      specify { subject.load(cities.map { |c| double(id: c.id) }, _type: type, scope: ->{ where(rating: 0) })
        .should == cities.first(2) + [nil] }
      specify { subject.load(cities.map { |c| double(id: c.id) },
        _type: type, scope: ->{ where(rating: 0) }, user: {scope: ->{ where(rating: 1)}})
        .should == [nil, nil] + cities.last(1) }
      specify { subject.load(cities.map { |c| double(id: c.id) }, _type: type, scope: City.where(rating: 1))
        .should == [nil, nil] + cities.last(1) }
      specify { subject.load(cities.map { |c| double(id: c.id) },
        _type: type, scope: City.where(rating: 1), user: {scope: ->{ where(rating: 0)}})
        .should == cities.first(2) + [nil] }
    end
  end
end

require 'spec_helper'
require 'timeout'

describe Chewy::Type::Adapter::ActiveRecord, :active_record do
  before { stub_model(:city) }
  before { stub_model(:country) }

  describe '#name' do
    specify { expect(described_class.new(City).name).to eq('City') }
    specify { expect(described_class.new(City.order(:id)).name).to eq('City') }
    specify { expect(described_class.new(City, name: 'town').name).to eq('Town') }

    context do
      before { stub_model('namespace/city') }

      specify { expect(described_class.new(Namespace::City).name).to eq('City') }
      specify { expect(described_class.new(Namespace::City.order(:id)).name).to eq('City') }
    end
  end

  describe '#default_scope' do
    specify { expect(described_class.new(City).default_scope).to eq(City.where(nil)) }
    specify { expect(described_class.new(City.order(:id)).default_scope).to eq(City.where(nil)) }
    specify { expect(described_class.new(City.limit(10)).default_scope).to eq(City.where(nil)) }
    specify { expect(described_class.new(City.offset(10)).default_scope).to eq(City.where(nil)) }
    specify { expect(described_class.new(City.where(rating: 10)).default_scope).to eq(City.where(rating: 10)) }
  end

  describe '#type_name' do
    specify { expect(described_class.new(City).type_name).to eq('city') }
    specify { expect(described_class.new(City.order(:id)).type_name).to eq('city') }
    specify { expect(described_class.new(City, name: 'town').type_name).to eq('town') }

    context do
      before { stub_model('namespace/city') }

      specify { expect(described_class.new(Namespace::City).type_name).to eq('city') }
      specify { expect(described_class.new(Namespace::City.order(:id)).type_name).to eq('city') }
    end
  end

  describe '#identify' do
    subject { described_class.new(City) }

    context do
      let!(:cities) { 3.times.map { City.create! } }

      specify { expect(subject.identify(City.where(nil))).to match_array(cities.map(&:id)) }
      specify { expect(subject.identify(cities)).to eq(cities.map(&:id)) }
      specify { expect(subject.identify(cities.first)).to eq([cities.first.id]) }
      specify { expect(subject.identify(cities.first(2).map(&:id))).to eq(cities.first(2).map(&:id)) }
    end

    context 'custom primary_key' do
      before { stub_model(:city) { self.primary_key = 'rating' } }
      let!(:cities) { 3.times.map { |i| City.create! { |c| c.rating = i } } }

      specify { expect(subject.identify(City.where(nil))).to match_array([0, 1, 2]) }
      specify { expect(subject.identify(cities)).to eq([0, 1, 2]) }
      specify { expect(subject.identify(cities.first)).to eq([0]) }
      specify { expect(subject.identify(cities.first(2).map(&:id))).to eq([0, 1]) }
    end
  end

  describe '#import' do
    def import(*args)
      result = []
      subject.import(*args) do |data|
        result.push data
        yield if block_given?
      end
      result
    end

    context do
      let!(:cities) { 3.times.map { City.create! } }
      let!(:deleted) { 4.times.map { City.create!.tap(&:destroy) } }
      subject { described_class.new(City) }

      specify { expect(import).to eq([{index: cities}]) }
      specify { expect(import nil).to eq([]) }

      specify { expect(import(City.order(:id))).to eq([{index: cities}]) }
      specify { expect(import(City.order(:id), batch_size: 2))
        .to eq([{index: cities.first(2)}, {index: cities.last(1)}]) }

      specify { expect(import(cities)).to eq([{index: cities}]) }
      specify { expect(import(cities, batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: cities.last(1)}]) }
      specify { expect(import(cities, deleted))
        .to eq([{index: cities}, {delete: deleted}]) }
      specify { expect(import(cities, deleted, batch_size: 2)).to eq([
        {index: cities.first(2)},
        {index: cities.last(1)},
        {delete: deleted.first(2)},
        {delete: deleted.last(2)}]) }

      specify { expect(import(cities.map(&:id))).to eq([{index: cities}]) }
      specify { expect(import(deleted.map(&:id))).to eq([{delete: deleted.map(&:id)}]) }
      specify { expect(import(cities.map(&:id), batch_size: 2))
        .to eq([{index: cities.first(2)}, {index: cities.last(1)}]) }
      specify { expect(import(cities.map(&:id), deleted.map(&:id)))
        .to eq([{index: cities}, {delete: deleted.map(&:id)}]) }
      specify { expect(import(cities.map(&:id), deleted.map(&:id), batch_size: 2)).to eq([
        {index: cities.first(2)},
        {index: cities.last(1)},
        {delete: deleted.first(2).map(&:id)},
        {delete: deleted.last(2).map(&:id)}]) }

      specify { expect(import(cities.first, nil)).to eq([{index: [cities.first]}]) }
      specify { expect(import(cities.first.id, nil)).to eq([{index: [cities.first]}]) }

      context 'timestamp ordered import' do
        around do |example|
          Timeout.timeout(1) { example.run }
        end

        context 'sorts by updated_at' do
          let!(:cities) { Array.new(3) { |index| City.create!(updated_at: index.hours.ago) } }
          let!(:deleted) { nil }


          specify { expect(import(City.unscoped, batch_size: 2, timestamp_ordered: true))
            .to eq([{index: cities.last(2).reverse}, {index: cities.first(1)}]) }
        end

        context 'is aware of objects updated in the middle of processing' do
          let!(:cities) { Array.new(3) { |index| City.create!(updated_at: index.hours.ago) } }
          let!(:deleted) { nil }

          specify do
            update_is_done = false

            results = import(City.unscoped, batch_size: 2, timestamp_ordered: true) do
              cities.last.touch unless update_is_done
              update_is_done = true
            end

            expect(results).to eq([{index: cities.last(2).reverse}, {index: [cities.first, cities.last]}])
          end
        end

        context 'finish even objects are updated every batch' do
          let!(:cities) { Array.new(3) { |index| City.create!(updated_at: index.hours.ago) } }
          let!(:deleted) { nil }

          specify do
            results = import(City.unscoped, batch_size: 2, timestamp_ordered: true) do
              City.order('updated_at asc').first.touch
            end

            expect(results).to eq([
              {index: cities.last(2).reverse},
              {index: [cities.first, cities.last]},
              {index: [cities[1]]}
            ])
          end
        end

        context 'fails if there is more objects updated every batch than batch size' do
          let!(:cities) { Array.new(3) { |index| City.create!(updated_at: index.hours.ago) } }
          let!(:deleted) { nil }

          specify do
            expect {
              import(City.unscoped, batch_size: 2, timestamp_ordered: true) do
                City.order('updated_at asc').first(2).map(&:touch)
              end
            }.to raise_error(Chewy::Type::Adapter::ActiveRecord::InfiniteImportWarning)
          end
        end

        context 'and timestamp is equal' do
          let(:update_time) { Time.now }
          let!(:cities) { Array.new(3) { City.create!(updated_at: update_time) } }
          let!(:deleted) { nil }

          specify { expect(import(City.unscoped, batch_size: 2, timestamp_ordered: true))
            .to eq([{index: cities.first(2)}, {index: cities.last(1)}]) }
        end

        context 'failback to id ordered import when field is missing' do
          subject { described_class.new(Country) }
          let!(:countries) { Array.new(3) { Country.create! } }
          let!(:deleted) { nil }

          specify { expect(import(Country.unscoped, batch_size: 2, timestamp_ordered: true))
            .to eq([{index: countries.first(2)}, {index: countries.last(1)}]) }
        end
      end
    end

    context 'additional delete conitions' do
      let!(:cities) { 4.times.map { |i| City.create! rating: i } }
      before { cities.last(2).map(&:destroy) }
      subject { described_class.new(City) }

      before do
        City.class_eval do
          def delete_already?
            rating.in?([1, 3])
          end
        end
      end
      subject { described_class.new(City, delete_if: ->{ delete_already? }) }

      specify { expect(import(City.where(nil))).to eq([
        { index: [cities[0]], delete: [cities[1]] }
      ]) }
      specify { expect(import(cities)).to eq([
        { index: [cities[0]], delete: [cities[1]] },
        { delete: cities.last(2) }
      ]) }
      specify { expect(import(cities.map(&:id))).to eq([
        { index: [cities[0]], delete: [cities[1]] },
        { delete: cities.last(2).map(&:id) }
      ]) }
    end

    context 'custom primary_key' do
      before { stub_model(:city) { self.primary_key = 'rating' } }
      let!(:cities) { 3.times.map { |i| City.create! { |c| c.rating = i + 7 } } }
      let!(:deleted) { 3.times.map { |i| City.create! { |c| c.rating = i + 10 }.tap(&:destroy) } }
      subject { described_class.new(City) }

      specify { expect(import).to eq([{index: cities}]) }

      specify { expect(import(City.order(:rating))).to eq([{index: cities}]) }
      specify { expect(import(City.order(:rating), batch_size: 2))
        .to eq([{index: cities.first(2)}, {index: cities.last(1)}]) }

      specify { expect(import(cities)).to eq([{index: cities}]) }
      specify { expect(import(cities, batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: cities.last(1)}]) }
      specify { expect(import(cities, deleted))
        .to eq([{index: cities}, {delete: deleted}]) }
      specify { expect(import(cities, deleted, batch_size: 2)).to eq([
        {index: cities.first(2)},
        {index: cities.last(1)},
        {delete: deleted.first(2)},
        {delete: deleted.last(1)}]) }

      specify { expect(import(cities.map(&:id))).to eq([{index: cities}]) }
      specify { expect(import(cities.map(&:id), batch_size: 2))
        .to eq([{index: cities.first(2)}, {index: cities.last(1)}]) }
      specify { expect(import(cities.map(&:id), deleted.map(&:id)))
        .to eq([{index: cities}, {delete: deleted.map(&:id)}]) }
      specify { expect(import(cities.map(&:id), deleted.map(&:id), batch_size: 2)).to eq([
        {index: cities.first(2)},
        {index: cities.last(1)},
        {delete: deleted.first(2).map(&:id)},
        {delete: deleted.last(1).map(&:id)}]) }
    end

    context 'default scope' do
      let!(:cities) { 4.times.map { |i| City.create!(rating: i/3) } }
      let!(:deleted) { 3.times.map { |i| City.create!.tap(&:destroy) } }
      subject { described_class.new(City.where(rating: 0)) }

      specify { expect(import).to eq([{index: cities.first(3)}]) }

      specify { expect(import(City.where('rating < 2')))
        .to eq([{index: cities.first(3)}]) }
      specify { expect(import(City.where('rating < 2'), batch_size: 2))
        .to eq([{index: cities.first(2)}, {index: [cities[2]]}]) }
      specify { expect(import(City.where('rating < 1')))
        .to eq([{index: cities.first(3)}]) }
      specify { expect(import(City.where('rating > 1'))).to eq([]) }

      specify { expect(import(cities.first(2)))
        .to eq([{index: cities.first(2)}]) }
      specify { expect(import(cities))
        .to eq([{index: cities.first(3)}, {delete: cities.last(1)}]) }
      specify { expect(import(cities, batch_size: 2))
        .to eq([{index: cities.first(2)}, {index: [cities[2]]}, {delete: cities.last(1)}]) }
      specify { expect(import(cities, deleted))
        .to eq([{index: cities.first(3)}, {delete: cities.last(1) + deleted}]) }
      specify { expect(import(cities, deleted, batch_size: 3)).to eq([
        {index: cities.first(3)},
        {delete: cities.last(1) + deleted.first(2)},
        {delete: deleted.last(1)}]) }

      specify { expect(import(cities.first(2).map(&:id)))
        .to eq([{index: cities.first(2)}]) }
      specify { expect(import(cities.map(&:id)))
        .to eq([{index: cities.first(3)}, {delete: [cities.last.id]}]) }
      specify { expect(import(cities.map(&:id), batch_size: 2))
        .to eq([{index: cities.first(2)}, {index: [cities[2]]}, {delete: [cities.last.id]}]) }
      specify { expect(import(cities.map(&:id), deleted.map(&:id)))
        .to eq([{index: cities.first(3)}, {delete: [cities.last.id] + deleted.map(&:id)}]) }
      specify { expect(import(cities.map(&:id), deleted.map(&:id), batch_size: 3)).to eq([
        {index: cities.first(3)},
        {delete: [cities.last.id] + deleted.first(2).map(&:id)},
        {delete: deleted.last(1).map(&:id)}]) }
    end

    context 'error handling' do
      let!(:cities) { 3.times.map { |i| City.create! } }
      let!(:deleted) { 2.times.map { |i| City.create!.tap(&:destroy) } }
      let(:ids) { (cities + deleted).map(&:id) }
      subject { described_class.new(City) }

      let(:data_comparer) do
        ->(id, data) { objects = data[:index] || data[:delete]; !objects.map { |o| o.respond_to?(:id) ? o.id : o }.include?(id) }
      end

      context 'implicit scope' do
        specify { expect(subject.import { |data| true }).to eq(true) }
        specify { expect(subject.import { |data| false }).to eq(false) }
        specify { expect(subject.import(batch_size: 1, &data_comparer.curry[cities[0].id])).to eq(false) }
        specify { expect(subject.import(batch_size: 1, &data_comparer.curry[cities[1].id])).to eq(false) }
        specify { expect(subject.import(batch_size: 1, &data_comparer.curry[cities[2].id])).to eq(false) }
        specify { expect(subject.import(batch_size: 1, &data_comparer.curry[deleted[0].id])).to eq(true) }
        specify { expect(subject.import(batch_size: 1, &data_comparer.curry[deleted[1].id])).to eq(true) }
      end

      context 'explicit scope' do
        let(:scope) { City.where(id: ids) }

        specify { expect(subject.import(scope) { |data| true }).to eq(true) }
        specify { expect(subject.import(scope) { |data| false }).to eq(false) }
        specify { expect(subject.import(scope, batch_size: 1, &data_comparer.curry[cities[0].id])).to eq(false) }
        specify { expect(subject.import(scope, batch_size: 1, &data_comparer.curry[cities[1].id])).to eq(false) }
        specify { expect(subject.import(scope, batch_size: 1, &data_comparer.curry[cities[2].id])).to eq(false) }
        specify { expect(subject.import(scope, batch_size: 1, &data_comparer.curry[deleted[0].id])).to eq(true) }
        specify { expect(subject.import(scope, batch_size: 1, &data_comparer.curry[deleted[1].id])).to eq(true) }
      end

      context 'objects' do
        specify { expect(subject.import(cities + deleted) { |data| true }).to eq(true) }
        specify { expect(subject.import(cities + deleted) { |data| false }).to eq(false) }
        specify { expect(subject.import(cities + deleted, batch_size: 1, &data_comparer.curry[cities[0].id])).to eq(false) }
        specify { expect(subject.import(cities + deleted, batch_size: 1, &data_comparer.curry[cities[1].id])).to eq(false) }
        specify { expect(subject.import(cities + deleted, batch_size: 1, &data_comparer.curry[cities[2].id])).to eq(false) }
        specify { expect(subject.import(cities + deleted, batch_size: 1, &data_comparer.curry[deleted[0].id])).to eq(false) }
        specify { expect(subject.import(cities + deleted, batch_size: 1, &data_comparer.curry[deleted[1].id])).to eq(false) }
      end

      context 'ids' do
        specify { expect(subject.import(ids) { |data| true }).to eq(true) }
        specify { expect(subject.import(ids) { |data| false }).to eq(false) }
        specify { expect(subject.import(ids, batch_size: 1, &data_comparer.curry[cities[0].id])).to eq(false) }
        specify { expect(subject.import(ids, batch_size: 1, &data_comparer.curry[cities[1].id])).to eq(false) }
        specify { expect(subject.import(ids, batch_size: 1, &data_comparer.curry[cities[2].id])).to eq(false) }
        specify { expect(subject.import(ids, batch_size: 1, &data_comparer.curry[deleted[0].id])).to eq(false) }
        specify { expect(subject.import(ids, batch_size: 1, &data_comparer.curry[deleted[1].id])).to eq(false) }
      end
    end
  end

  describe '#load' do
    context do
      let!(:cities) { 3.times.map { |i| City.create!(rating: i/2) } }
      let!(:deleted) { 2.times.map { |i| City.create!.tap(&:destroy) } }

      let(:type) { double(type_name: 'user') }

      subject { described_class.new(City) }

      specify { expect(subject.load(cities.map { |c| double(id: c.id) }, _type: type)).to eq(cities) }
      specify { expect(subject.load(cities.map { |c| double(id: c.id) }.reverse, _type: type)).to eq(cities.reverse) }
      specify { expect(subject.load(deleted.map { |c| double(id: c.id) }, _type: type)).to eq([nil, nil]) }
      specify { expect(subject.load((cities + deleted).map { |c| double(id: c.id) }, _type: type)).to eq([*cities, nil, nil]) }
      specify { expect(subject.load(cities.map { |c| double(id: c.id) }, _type: type, scope: ->{ where(rating: 0) }))
        .to eq(cities.first(2) + [nil]) }
      specify { expect(subject.load(cities.map { |c| double(id: c.id) },
        _type: type, scope: ->{ where(rating: 0) }, user: {scope: ->{ where(rating: 1)}}))
        .to eq([nil, nil] + cities.last(1)) }
      specify { expect(subject.load(cities.map { |c| double(id: c.id) }, _type: type, scope: City.where(rating: 1)))
        .to eq([nil, nil] + cities.last(1)) }
      specify { expect(subject.load(cities.map { |c| double(id: c.id) },
        _type: type, scope: City.where(rating: 1), user: {scope: ->{ where(rating: 0)}}))
        .to eq(cities.first(2) + [nil]) }
    end

    context 'custom primary_key' do
      before { stub_model(:city) { self.primary_key = 'rating' } }
      let!(:cities) { 3.times.map { |i| City.create!(country_id: i/2) { |c| c.rating = i + 7 } } }
      let!(:deleted) { 2.times.map { |i| City.create! { |c| c.rating = i + 10 }.tap(&:destroy) } }

      let(:type) { double(type_name: 'user') }

      subject { described_class.new(City) }

      specify { expect(subject.load(cities.map { |c| double(id: c.id) }, _type: type)).to eq(cities) }
      specify { expect(subject.load(cities.map { |c| double(id: c.id) }.reverse, _type: type)).to eq(cities.reverse) }
      specify { expect(subject.load(deleted.map { |c| double(id: c.id) }, _type: type)).to eq([nil, nil]) }
      specify { expect(subject.load((cities + deleted).map { |c| double(id: c.id) }, _type: type)).to eq([*cities, nil, nil]) }
      specify { expect(subject.load(cities.map { |c| double(id: c.id) }, _type: type, scope: ->{ where(country_id: 0) }))
        .to eq(cities.first(2) + [nil]) }
      specify { expect(subject.load(cities.map { |c| double(id: c.id) },
        _type: type, scope: ->{ where(country_id: 0) }, user: {scope: ->{ where(country_id: 1)}}))
        .to eq([nil, nil] + cities.last(1)) }
      specify { expect(subject.load(cities.map { |c| double(id: c.id) }, _type: type, scope: City.where(country_id: 1)))
        .to eq([nil, nil] + cities.last(1)) }
      specify { expect(subject.load(cities.map { |c| double(id: c.id) },
        _type: type, scope: City.where(country_id: 1), user: {scope: ->{ where(country_id: 0)}}))
        .to eq(cities.first(2) + [nil]) }
    end
  end
end

require 'spec_helper'

RawCity = Struct.new(:id) do
  def rating
    id * 10
  end
end

describe Chewy::Index::Adapter::ActiveRecord, :active_record do
  before do
    stub_model(:city)
    stub_model(:country)
    City.belongs_to :country
    Country.has_many :cities
  end

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

  describe '.new' do
    context 'with logger' do
      let(:test_logger) { Logger.new('/dev/null') }
      let(:default_scope_behavior) { :warn }

      around do |example|
        previous_logger = Chewy.logger
        Chewy.logger = test_logger

        previous_default_scope_behavior = Chewy.config.import_scope_cleanup_behavior
        Chewy.config.import_scope_cleanup_behavior = default_scope_behavior

        example.run
      ensure
        Chewy.logger = previous_logger
        Chewy.config.import_scope_cleanup_behavior = previous_default_scope_behavior
      end

      specify do
        expect(test_logger).to receive(:warn)
        described_class.new(City.order(:id))
      end

      specify do
        expect(test_logger).to receive(:warn)
        described_class.new(City.offset(10))
      end

      specify do
        expect(test_logger).to receive(:warn)
        described_class.new(City.limit(10))
      end

      context 'ignore import scope warning' do
        let(:default_scope_behavior) { :ignore }

        specify do
          expect(test_logger).not_to receive(:warn)
          described_class.new(City.order(:id))
        end

        specify do
          expect(test_logger).not_to receive(:warn)
          described_class.new(City.offset(10))
        end

        specify do
          expect(test_logger).not_to receive(:warn)
          described_class.new(City.limit(10))
        end
      end

      context 'raise exception on import scope with order/limit/offset' do
        let(:default_scope_behavior) { :raise }

        specify { expect { described_class.new(City.order(:id)) }.to raise_error(Chewy::ImportScopeCleanupError) }
        specify { expect { described_class.new(City.limit(10)) }.to raise_error(Chewy::ImportScopeCleanupError) }
        specify { expect { described_class.new(City.offset(10)) }.to raise_error(Chewy::ImportScopeCleanupError) }
      end
    end
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
      let!(:cities) { Array.new(3) { City.create! } }

      specify { expect(subject.identify(City.where(nil))).to match_array(cities.map(&:id)) }
      specify { expect(subject.identify(cities)).to eq(cities.map(&:id)) }
      specify { expect(subject.identify(cities.first)).to eq([cities.first.id]) }
      specify { expect(subject.identify(cities.first(2).map(&:id))).to eq(cities.first(2).map(&:id)) }
    end

    context 'custom primary_key' do
      before { stub_model(:city) { self.primary_key = 'rating' } }
      let!(:cities) { Array.new(3) { |i| City.create! { |c| c.rating = i } } }

      specify { expect(subject.identify(City.where(nil))).to match_array([0, 1, 2]) }
      specify { expect(subject.identify(cities)).to eq([0, 1, 2]) }
      specify { expect(subject.identify(cities.first)).to eq([0]) }
      specify { expect(subject.identify(cities.first(2).map(&:id))).to eq([0, 1]) }
    end
  end

  describe '#import' do
    def import(*args)
      result = []
      subject.import(*args) { |data| result.push data }
      result
    end

    context do
      let!(:cities) { Array.new(3) { City.create! } }
      let!(:deleted) { Array.new(4) { City.create!.tap(&:destroy) } }
      subject { described_class.new(City) }

      specify { expect(import).to eq([{index: cities}]) }
      specify { expect(import(nil)).to eq([]) }

      specify { expect(import(City.order(:id))).to eq([{index: cities}]) }
      specify do
        expect(import(City.order(:id), batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: cities.last(1)}])
      end

      specify do
        cities
        expects_db_queries do
          expect(import(cities, direct_import: false)).to eq([{index: cities}])
        end
      end
      specify do
        cities
        expects_no_query do
          expect(import(cities, direct_import: true)).to eq([{index: cities}])
        end
      end

      specify do
        expect(import(cities, batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: cities.last(1)}])
      end
      specify do
        expect(import(cities, deleted))
          .to eq([{index: cities}, {delete: deleted}])
      end
      specify do
        expect(import(cities, deleted, batch_size: 2)).to eq([
          {index: cities.first(2)},
          {index: cities.last(1)},
          {delete: deleted.first(2)},
          {delete: deleted.last(2)}
        ])
      end

      specify { expect(import(cities.map(&:id))).to eq([{index: cities}]) }
      specify { expect(import(deleted.map(&:id))).to eq([{delete: deleted.map(&:id)}]) }
      specify do
        expect(import(cities.map(&:id), batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: cities.last(1)}])
      end
      specify do
        expect(import(cities.map(&:id), deleted.map(&:id)))
          .to eq([{index: cities}, {delete: deleted.map(&:id)}])
      end
      specify do
        expect(import(cities.map(&:id), deleted.map(&:id), batch_size: 2)).to eq([
          {index: cities.first(2)},
          {index: cities.last(1)},
          {delete: deleted.first(2).map(&:id)},
          {delete: deleted.last(2).map(&:id)}
        ])
      end

      specify { expect(import(cities.first, nil)).to eq([{index: [cities.first]}]) }
      specify { expect(import(cities.first.id, nil)).to eq([{index: [cities.first]}]) }

      context 'raw_import' do
        before do
          stub_class(:dummy_city) do
            def initialize(attributes = {})
              @attributes = attributes
            end

            def method_missing(name, *args, &block)
              if @attributes.key?(name.to_s)
                @attributes[name.to_s]
              else
                super
              end
            end

            def respond_to_missing?(name, _)
              @attributes.key?(name.to_s)
            end
          end
        end
        let!(:cities) { Array.new(3) { |i| City.create!(id: i + 1, name: "City#{i + 1}") } }
        let(:converter) { ->(hash) { DummyCity.new(hash) } }

        it 'uses the raw import converter to make objects out of raw hashes from the database' do
          expect(City).not_to receive(:new)

          expect(import(City.where(nil), raw_import: converter)).to match([{index: match_array([
            an_instance_of(DummyCity).and(have_attributes(id: 1, name: 'City1')),
            an_instance_of(DummyCity).and(have_attributes(id: 2, name: 'City2')),
            an_instance_of(DummyCity).and(have_attributes(id: 3, name: 'City3'))
          ])}])
        end

        specify do
          expect(import([1, 2, 3], raw_import: converter)).to match([{index: match_array([
            an_instance_of(DummyCity).and(have_attributes(id: 1, name: 'City1')),
            an_instance_of(DummyCity).and(have_attributes(id: 2, name: 'City2')),
            an_instance_of(DummyCity).and(have_attributes(id: 3, name: 'City3'))
          ])}])
        end

        specify do
          expect(import(cities, raw_import: converter)).to match([{index: match_array([
            an_instance_of(DummyCity).and(have_attributes(id: 1, name: 'City1')),
            an_instance_of(DummyCity).and(have_attributes(id: 2, name: 'City2')),
            an_instance_of(DummyCity).and(have_attributes(id: 3, name: 'City3'))
          ])}])
        end
      end
    end

    context 'additional delete conditions' do
      let!(:cities) { Array.new(4) { |i| City.create! rating: i } }
      before { cities.last(2).map(&:destroy) }
      subject { described_class.new(City) }

      before do
        City.class_eval do
          def delete_already?
            rating.in?([1, 3])
          end
        end
      end
      subject { described_class.new(City, delete_if: -> { delete_already? }) }

      specify do
        expect(import(City.where(nil))).to eq([
          {index: [cities[0]], delete: [cities[1]]}
        ])
      end
      specify do
        expect(import(cities)).to eq([
          {index: [cities[0]], delete: [cities[1]]},
          {delete: cities.last(2)}
        ])
      end
      specify do
        expect(import(cities.map(&:id))).to eq([
          {index: [cities[0]], delete: [cities[1]]},
          {delete: cities.last(2).map(&:id)}
        ])
      end
    end

    context 'custom primary_key' do
      before { stub_model(:city) { self.primary_key = 'rating' } }
      let!(:cities) { Array.new(3) { |i| City.create! { |c| c.rating = i + 7 } } }
      let!(:deleted) { Array.new(3) { |i| City.create! { |c| c.rating = i + 10 }.tap(&:destroy) } }
      subject { described_class.new(City) }

      specify { expect(import).to eq([{index: cities}]) }

      specify { expect(import(City.order(:rating))).to eq([{index: cities}]) }
      specify do
        expect(import(City.order(:rating), batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: cities.last(1)}])
      end

      specify { expect(import(cities)).to eq([{index: cities}]) }
      specify do
        expect(import(cities, batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: cities.last(1)}])
      end
      specify do
        expect(import(cities, deleted))
          .to eq([{index: cities}, {delete: deleted}])
      end
      specify do
        expect(import(cities, deleted, batch_size: 2)).to eq([
          {index: cities.first(2)},
          {index: cities.last(1)},
          {delete: deleted.first(2)},
          {delete: deleted.last(1)}
        ])
      end

      specify { expect(import(cities.map(&:id))).to eq([{index: cities}]) }
      specify do
        expect(import(cities.map(&:id), batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: cities.last(1)}])
      end
      specify do
        expect(import(cities.map(&:id), deleted.map(&:id)))
          .to eq([{index: cities}, {delete: deleted.map(&:id)}])
      end
      specify do
        expect(import(cities.map(&:id), deleted.map(&:id), batch_size: 2)).to eq([
          {index: cities.first(2)},
          {index: cities.last(1)},
          {delete: deleted.first(2).map(&:id)},
          {delete: deleted.last(1).map(&:id)}
        ])
      end
    end

    context 'default scope' do
      let!(:cities) { Array.new(4) { |i| City.create!(rating: i / 3) } }
      let!(:deleted) { Array.new(3) { City.create!.tap(&:destroy) } }
      subject { described_class.new(City.where(rating: 0)) }

      specify { expect(import).to eq([{index: cities.first(3)}]) }

      specify do
        expect(import(City.where('rating < 2')))
          .to eq([{index: cities.first(3)}])
      end
      specify do
        expect(import(City.where('rating < 2'), batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: [cities[2]]}])
      end
      specify do
        expect(import(City.where('rating < 1')))
          .to eq([{index: cities.first(3)}])
      end
      specify { expect(import(City.where('rating > 1'))).to eq([]) }

      specify do
        expect(import(cities.first(2)))
          .to eq([{index: cities.first(2)}])
      end
      specify do
        expect(import(cities))
          .to eq([{index: cities.first(3)}, {delete: cities.last(1)}])
      end
      specify do
        expect(import(cities, batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: [cities[2]]}, {delete: cities.last(1)}])
      end
      specify do
        expect(import(cities, deleted))
          .to eq([{index: cities.first(3)}, {delete: cities.last(1) + deleted}])
      end
      specify do
        expect(import(cities, deleted, batch_size: 3)).to eq([
          {index: cities.first(3)},
          {delete: cities.last(1) + deleted.first(2)},
          {delete: deleted.last(1)}
        ])
      end

      specify do
        expect(import(cities.first(2).map(&:id)))
          .to eq([{index: cities.first(2)}])
      end
      specify do
        expect(import(cities.map(&:id)))
          .to eq([{index: cities.first(3)}, {delete: [cities.last.id]}])
      end
      specify do
        expect(import(cities.map(&:id), batch_size: 2))
          .to eq([{index: cities.first(2)}, {index: [cities[2]]}, {delete: [cities.last.id]}])
      end
      specify do
        expect(import(cities.map(&:id), deleted.map(&:id)))
          .to eq([{index: cities.first(3)}, {delete: [cities.last.id] + deleted.map(&:id)}])
      end
      specify do
        expect(import(cities.map(&:id), deleted.map(&:id), batch_size: 3)).to eq([
          {index: cities.first(3)},
          {delete: [cities.last.id] + deleted.first(2).map(&:id)},
          {delete: deleted.last(1).map(&:id)}
        ])
      end
    end

    context 'error handling' do
      let!(:cities) { Array.new(3) { City.create! } }
      let!(:deleted) { Array.new(2) { City.create!.tap(&:destroy) } }
      let(:ids) { (cities + deleted).map(&:id) }
      subject { described_class.new(City) }

      let(:data_comparer) do
        lambda do |id, data|
          objects = data[:index] || data[:delete]
          !objects.map { |o| o.respond_to?(:id) ? o.id : o }.include?(id)
        end
      end

      context 'implicit scope' do
        specify { expect(subject.import { |_data| true }).to eq(true) }
        specify { expect(subject.import { |_data| false }).to eq(false) }
        specify { expect(subject.import(batch_size: 1, &data_comparer.curry[cities[0].id])).to eq(false) }
        specify { expect(subject.import(batch_size: 1, &data_comparer.curry[cities[1].id])).to eq(false) }
        specify { expect(subject.import(batch_size: 1, &data_comparer.curry[cities[2].id])).to eq(false) }
        specify { expect(subject.import(batch_size: 1, &data_comparer.curry[deleted[0].id])).to eq(true) }
        specify { expect(subject.import(batch_size: 1, &data_comparer.curry[deleted[1].id])).to eq(true) }
      end

      context 'explicit scope' do
        let(:scope) { City.where(id: ids) }

        specify { expect(subject.import(scope) { |_data| true }).to eq(true) }
        specify { expect(subject.import(scope) { |_data| false }).to eq(false) }
        specify { expect(subject.import(scope, batch_size: 1, &data_comparer.curry[cities[0].id])).to eq(false) }
        specify { expect(subject.import(scope, batch_size: 1, &data_comparer.curry[cities[1].id])).to eq(false) }
        specify { expect(subject.import(scope, batch_size: 1, &data_comparer.curry[cities[2].id])).to eq(false) }
        specify { expect(subject.import(scope, batch_size: 1, &data_comparer.curry[deleted[0].id])).to eq(true) }
        specify { expect(subject.import(scope, batch_size: 1, &data_comparer.curry[deleted[1].id])).to eq(true) }
      end

      context 'objects' do
        specify { expect(subject.import(cities + deleted) { |_data| true }).to eq(true) }
        specify { expect(subject.import(cities + deleted) { |_data| false }).to eq(false) }
        specify do
          expect(subject.import(cities + deleted, batch_size: 1, &data_comparer.curry[cities[0].id])).to eq(false)
        end
        specify do
          expect(subject.import(cities + deleted, batch_size: 1, &data_comparer.curry[cities[1].id])).to eq(false)
        end
        specify do
          expect(subject.import(cities + deleted, batch_size: 1, &data_comparer.curry[cities[2].id])).to eq(false)
        end
        specify do
          expect(subject.import(cities + deleted, batch_size: 1, &data_comparer.curry[deleted[0].id])).to eq(false)
        end
        specify do
          expect(subject.import(cities + deleted, batch_size: 1, &data_comparer.curry[deleted[1].id])).to eq(false)
        end
      end

      context 'ids' do
        specify { expect(subject.import(ids) { |_data| true }).to eq(true) }
        specify { expect(subject.import(ids) { |_data| false }).to eq(false) }
        specify { expect(subject.import(ids, batch_size: 1, &data_comparer.curry[cities[0].id])).to eq(false) }
        specify { expect(subject.import(ids, batch_size: 1, &data_comparer.curry[cities[1].id])).to eq(false) }
        specify { expect(subject.import(ids, batch_size: 1, &data_comparer.curry[cities[2].id])).to eq(false) }
        specify { expect(subject.import(ids, batch_size: 1, &data_comparer.curry[deleted[0].id])).to eq(false) }
        specify { expect(subject.import(ids, batch_size: 1, &data_comparer.curry[deleted[1].id])).to eq(false) }
      end
    end
  end

  describe '#import_fields' do
    subject { described_class.new(Country) }
    let!(:countries) { Array.new(3) { |i| Country.create!(rating: i) { |c| c.id = i + 1 } } }
    let!(:cities) { Array.new(6) { |i| City.create!(rating: i + 3, country_id: (i + 4) / 2) { |c| c.id = i + 3 } } }

    specify { expect(subject.import_fields).to match([contain_exactly(1, 2, 3)]) }
    specify { expect(subject.import_fields(fields: [:rating])).to match([contain_exactly([1, 0], [2, 1], [3, 2])]) }

    context 'scopes' do
      context do
        subject { described_class.new(Country.includes(:cities)) }

        specify { expect(subject.import_fields).to match([contain_exactly(1, 2, 3)]) }
        specify { expect(subject.import_fields(fields: [:rating])).to match([contain_exactly([1, 0], [2, 1], [3, 2])]) }
      end

      context do
        subject { described_class.new(Country.joins(:cities)) }

        specify { expect(subject.import_fields).to match([contain_exactly(2, 3)]) }
        specify { expect(subject.import_fields(fields: [:rating])).to match([contain_exactly([2, 1], [3, 2])]) }
      end

      context 'ignores default scope if another scope is passed' do
        subject { described_class.new(Country.joins(:cities)) }

        specify { expect(subject.import_fields(Country.where('rating < 2'))).to match([contain_exactly(1, 2)]) }
        specify do
          expect(subject.import_fields(Country.where('rating < 2'), fields: [:rating]))
            .to match([contain_exactly([1, 0], [2, 1])])
        end
      end
    end

    context 'objects/ids' do
      specify { expect(subject.import_fields(1, 2)).to match([contain_exactly(1, 2)]) }
      specify { expect(subject.import_fields(1, 2, fields: [:rating])).to match([contain_exactly([1, 0], [2, 1])]) }

      specify { expect(subject.import_fields(countries.first(2))).to match([contain_exactly(1, 2)]) }
      specify do
        expect(subject.import_fields(countries.first(2), fields: [:rating]))
          .to match([contain_exactly([1, 0], [2, 1])])
      end
    end

    context 'batch_size' do
      specify { expect(subject.import_fields(batch_size: 2)).to match([contain_exactly(1, 2), [3]]) }
      specify do
        expect(subject.import_fields(batch_size: 2, fields: [:rating]))
          .to match([contain_exactly([1, 0], [2, 1]), [[3, 2]]])
      end

      specify do
        expect(subject.import_fields(Country.where('rating < 2'), batch_size: 2))
          .to match([contain_exactly(1, 2)])
      end
      specify do
        expect(subject.import_fields(Country.where('rating < 2'), batch_size: 2, fields: [:rating]))
          .to match([contain_exactly([1, 0], [2, 1])])
      end

      specify { expect(subject.import_fields(1, 2, batch_size: 1)).to match([[1], [2]]) }
      specify { expect(subject.import_fields(1, 2, batch_size: 1, fields: [:rating])).to match([[[1, 0]], [[2, 1]]]) }

      specify { expect(subject.import_fields(countries.first(2), batch_size: 1)).to match([[1], [2]]) }
      specify do
        expect(subject.import_fields(countries.first(2), batch_size: 1, fields: [:rating]))
          .to match([[[1, 0]], [[2, 1]]])
      end
    end

    context 'typecast' do
      specify { expect(subject.import_fields(typecast: false)).to match([contain_exactly(1, 2, 3)]) }
      specify do
        expect(subject.import_fields(fields: [:updated_at]).to_a)
          .to match([contain_exactly(
            [1, an_instance_of(Time)],
            [2, an_instance_of(Time)],
            [3, an_instance_of(Time)]
          )])
      end
      specify do
        expect(subject.import_fields(fields: [:updated_at], typecast: false))
          .to match([contain_exactly(
            [1, match(/#{Time.now.utc.strftime('%Y-%m-%d')}/)],
            [2, match(/#{Time.now.utc.strftime('%Y-%m-%d')}/)],
            [3, match(/#{Time.now.utc.strftime('%Y-%m-%d')}/)]
          )])
      end
    end
  end

  describe '#load' do
    context do
      let!(:cities) { Array.new(3) { |i| City.create!(rating: i / 2) } }
      let!(:deleted) { Array.new(2) { City.create!.tap(&:destroy) } }
      let(:city_ids) { cities.map(&:id) }
      let(:deleted_ids) { deleted.map(&:id) }

      subject { described_class.new(City) }

      specify { expect(subject.load(city_ids, _index: 'users')).to eq(cities) }
      specify { expect(subject.load(city_ids.reverse, _index: 'users')).to eq(cities.reverse) }
      specify { expect(subject.load(deleted_ids, _index: 'users')).to eq([nil, nil]) }
      specify { expect(subject.load(city_ids + deleted_ids, _index: 'users')).to eq([*cities, nil, nil]) }
      specify do
        expect(subject.load(city_ids, _index: 'users', scope: -> { where(rating: 0) }))
          .to eq(cities.first(2) + [nil])
      end
      specify do
        expect(
          subject.load(city_ids, _index: 'users', scope: -> { where(rating: 0) }, users: {scope: -> { where(rating: 1) }})
        ).to eq([nil, nil] + cities.last(1))
      end
      specify do
        expect(subject.load(city_ids, _index: 'users', scope: City.where(rating: 1)))
          .to eq([nil, nil] + cities.last(1))
      end
      specify do
        expect(
          subject.load(city_ids, _index: 'users', scope: City.where(rating: 1), users: {scope: -> { where(rating: 0) }})
        ).to eq(cities.first(2) + [nil])
      end
    end

    context 'custom primary_key' do
      before { stub_model(:city) { self.primary_key = 'rating' } }
      let!(:cities) { Array.new(3) { |i| City.create!(country_id: i / 2) { |c| c.rating = i + 7 } } }
      let!(:deleted) { Array.new(2) { |i| City.create! { |c| c.rating = i + 10 }.tap(&:destroy) } }
      let(:city_ids) { cities.map(&:rating) }
      let(:deleted_ids) { deleted.map(&:rating) }

      subject { described_class.new(City) }

      specify { expect(subject.load(city_ids, _index: 'users')).to eq(cities) }
      specify { expect(subject.load(city_ids.reverse, _index: 'users')).to eq(cities.reverse) }
      specify { expect(subject.load(deleted_ids, _index: 'users')).to eq([nil, nil]) }
      specify { expect(subject.load(city_ids + deleted_ids, _index: 'users')).to eq([*cities, nil, nil]) }
      specify do
        expect(subject.load(city_ids, _index: 'users', scope: -> { where(country_id: 0) }))
          .to eq(cities.first(2) + [nil])
      end
      specify do
        expect(
          subject.load(
            city_ids, _index: 'users', scope: -> { where(country_id: 0) }, users: {scope: -> { where(country_id: 1) }}
          )
        ).to eq([nil, nil] + cities.last(1))
      end
      specify do
        expect(subject.load(city_ids, _index: 'users', scope: City.where(country_id: 1)))
          .to eq([nil, nil] + cities.last(1))
      end
      specify do
        expect(
          subject.load(
            city_ids, _index: 'users', scope: City.where(country_id: 1), users: {scope: -> { where(country_id: 0) }}
          )
        ).to eq(cities.first(2) + [nil])
      end
    end

    context 'with raw_import option' do
      subject { described_class.new(City) }

      let!(:cities) { Array.new(3) { |i| City.create!(rating: i / 2) } }
      let(:city_ids) { cities.map(&:id) }

      let(:raw_import) { ->(hash) { RawCity.new(hash['id']) } }
      it 'uses the custom loader' do
        raw_cities = subject.load(city_ids, _index: 'cities', raw_import: raw_import).map do |c|
          {id: c.id, rating: c.rating}
        end

        expect(raw_cities).to eq([
          {id: 1, rating: 10},
          {id: 2, rating: 20},
          {id: 3, rating: 30}
        ])
      end
    end
  end
end

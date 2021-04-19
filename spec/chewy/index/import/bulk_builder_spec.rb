require 'spec_helper'

describe Chewy::Index::Import::BulkBuilder do
  before { Chewy.massacre }

  subject { described_class.new(index, to_index: to_index, delete: delete, fields: fields) }
  let(:index) { CitiesIndex }
  let(:to_index) { [] }
  let(:delete) { [] }
  let(:fields) { [] }

  describe '#bulk_body' do
    context 'simple bulk', :orm do
      before do
        stub_model(:city)
        stub_index(:cities) do
          index_scope City
          field :name, :rating
        end
      end
      let(:cities) { Array.new(3) { |i| City.create!(id: i + 1, name: "City#{i + 17}", rating: 42) } }

      specify { expect(subject.bulk_body).to eq([]) }

      context do
        let(:to_index) { cities }
        specify do
          expect(subject.bulk_body).to eq([
            {index: {_id: 1, data: {'name' => 'City17', 'rating' => 42}}},
            {index: {_id: 2, data: {'name' => 'City18', 'rating' => 42}}},
            {index: {_id: 3, data: {'name' => 'City19', 'rating' => 42}}}
          ])
        end
      end

      context do
        let(:delete) { cities }
        specify do
          expect(subject.bulk_body).to eq([
            {delete: {_id: 1}}, {delete: {_id: 2}}, {delete: {_id: 3}}
          ])
        end
      end

      context do
        let(:to_index) { cities.first(2) }
        let(:delete) { [cities.last] }
        specify do
          expect(subject.bulk_body).to eq([
            {index: {_id: 1, data: {'name' => 'City17', 'rating' => 42}}},
            {index: {_id: 2, data: {'name' => 'City18', 'rating' => 42}}},
            {delete: {_id: 3}}
          ])
        end

        context ':fields' do
          let(:fields) { %w[name] }
          specify do
            expect(subject.bulk_body).to eq([
              {update: {_id: 1, data: {doc: {'name' => 'City17'}}}},
              {update: {_id: 2, data: {doc: {'name' => 'City18'}}}},
              {delete: {_id: 3}}
            ])
          end
        end
      end
    end

    context 'custom id', :orm do
      before do
        stub_model(:city)
      end

      before do
        stub_index(:cities) do
          index_scope City
          root id: -> { name } do
            field :rating
          end
        end
      end

      let(:london) { City.create(id: 1, name: 'London', rating: 4) }

      specify do
        expect { CitiesIndex.import(london) }
          .to update_index(CitiesIndex).and_reindex(london.name)
      end

      context 'indexing' do
        let(:to_index) { [london] }

        specify do
          expect(subject.bulk_body).to eq([
            {index: {_id: london.name, data: {'rating' => 4}}}
          ])
        end
      end

      context 'destroying' do
        let(:delete) { [london] }

        specify do
          expect(subject.bulk_body).to eq([
            {delete: {_id: london.name}}
          ])
        end
      end
    end

    context 'crutches' do
      before do
        stub_index(:cities) do
          crutch :names do |collection|
            collection.map { |item| [item.id, "Name#{item.id}"] }.to_h
          end

          field :name, value: ->(o, c) { c.names[o.id] }
        end
      end

      let(:to_index) { [double(id: 42)] }

      specify do
        expect(subject.bulk_body).to eq([
          {index: {_id: 42, data: {'name' => 'Name42'}}}
        ])
      end

      context 'witchcraft' do
        before { CitiesIndex.witchcraft! }
        specify do
          expect(subject.bulk_body).to eq([
            {index: {_id: 42, data: {'name' => 'Name42'}}}
          ])
        end
      end
    end

    context 'empty ids' do
      before do
        stub_index(:cities) do
          field :name
        end
      end

      let(:to_index) { [{id: 1, name: 'Name0'}, double(id: '', name: 'Name1'), double(name: 'Name2')] }
      let(:delete) { [double(id: '', name: 'Name3'), {name: 'Name4'}, '', 2] }

      specify do
        expect(subject.bulk_body).to eq([
          {index: {_id: 1, data: {'name' => 'Name0'}}},
          {index: {data: {'name' => 'Name1'}}},
          {index: {data: {'name' => 'Name2'}}},
          {delete: {_id: {'name' => 'Name4'}}},
          {delete: {_id: 2}}
        ])
      end

      context do
        let(:fields) { %w[name] }

        specify do
          expect(subject.bulk_body).to eq([
            {update: {_id: 1, data: {doc: {'name' => 'Name0'}}}},
            {delete: {_id: {'name' => 'Name4'}}},
            {delete: {_id: 2}}
          ])
        end
      end
    end
  end

  describe '#index_objects_by_id' do
    before do
      stub_index(:cities) do
        field :name
      end
    end

    let(:to_index) { [double(id: 1), double(id: 2), double(id: ''), double] }
    let(:delete) { [double(id: 3)] }

    specify { expect(subject.index_objects_by_id).to eq('1' => to_index.first, '2' => to_index.second) }
  end
end

# frozen_string_literal: true

require 'spec_helper'

describe Chewy::Index do
  before do
    stub_index(:dummies)
  end

  describe '.import', :orm do
    before do
      stub_model(:city)
      stub_model(:country)

      stub_index(:cities) do
        index_scope City
      end

      stub_index(:countries) do
        index_scope Country
      end
    end

    let!(:cities) { Array.new(2) { |i| City.create! id: i + 1 } }
    let!(:countries) { Array.new(2) { |i| Country.create! id: i + 1 } }

    specify do
      expect { CitiesIndex.import }.to update_index(CitiesIndex).and_reindex(cities)
      expect { CountriesIndex.import }.to update_index(CountriesIndex).and_reindex(countries)
    end

    specify do
      expect { CitiesIndex.import cities.first }.to update_index(CitiesIndex).and_reindex(cities.first).only
      expect { CountriesIndex.import countries.last }.to update_index(CountriesIndex).and_reindex(countries.last).only
    end

    specify do
      expect(CitiesIndex.client).to receive(:bulk).with(hash_including(refresh: false)).once
      CitiesIndex.import cities.first, refresh: false
    end
  end

  describe '.client' do
    specify { expect(stub_index(:dummies1).client).to eq(stub_index(:dummies2).client) }

    context do
      before do
        stub_index(:dummies1)
        stub_index(:dummies2, Dummies1Index)
      end

      specify { expect(Dummies1Index.client).to eq(Dummies2Index.client) }
    end
  end

  describe '.index_name' do
    specify { expect { Class.new(Chewy::Index).index_name }.to raise_error Chewy::UndefinedIndex }
    specify { expect(Class.new(Chewy::Index) { index_name :myindex }.index_name).to eq('myindex') }
    specify { expect(stub_const('DeveloperIndex', Class.new(Chewy::Index)).index_name).to eq('developer') }
    specify { expect(stub_const('DevelopersIndex', Class.new(Chewy::Index)).index_name).to eq('developers') }

    specify do
      expect(stub_const('DevelopersIndex', Class.new(Chewy::Index)).index_name(suffix: '')).to eq('developers')
    end
    specify do
      expect(stub_const('DevelopersIndex', Class.new(Chewy::Index)).index_name(suffix: '2013')).to eq('developers_2013')
    end
    specify do
      expect(stub_const('DevelopersIndex', Class.new(Chewy::Index)).index_name(prefix: '')).to eq('developers')
    end
    specify do
      expect(stub_const('DevelopersIndex', Class.new(Chewy::Index)).index_name(prefix: 'test')).to eq('test_developers')
    end

    context do
      before { allow(Chewy).to receive_messages(configuration: {prefix: 'testing'}) }
      specify { expect(DummiesIndex.index_name).to eq('testing_dummies') }
      specify { expect(stub_index(:dummies) { index_name :users }.index_name).to eq('testing_users') }
      specify { expect(stub_index(:dummies) { index_name :users }.index_name(prefix: '')).to eq('users') }
    end
  end

  describe '.derivable_name' do
    specify { expect(Class.new(Chewy::Index).derivable_name).to be_nil }
    specify { expect(stub_index(:places).derivable_name).to eq('places') }
    specify { expect(stub_index('namespace/places').derivable_name).to eq('namespace/places') }
  end

  describe '.prefix' do
    before { allow(Chewy).to receive_messages(configuration: {prefix: 'testing'}) }
    specify { expect(Class.new(Chewy::Index).prefix).to eq('testing') }
  end

  describe '.index_scope' do
    specify { expect(DummiesIndex.adapter.name).to eq('Default') }

    context do
      before { stub_index(:dummies) { index_scope :dummy, name: :borogoves } }
      specify { expect(DummiesIndex.adapter.name).to eq('Borogoves') }
    end

    context do
      before { stub_class(:city) }
      before { stub_index(:dummies) { index_scope City, name: :country } }
      specify { expect(DummiesIndex.adapter.name).to eq('Country') }
    end

    context do
      before { stub_class('City') }
      before { stub_class('Country') }

      specify do
        expect do
          Kernel.eval <<-DUMMY_CITY_INDEX
            class DummyCityIndex2 < Chewy::Index
              index_scope City
              index_scope Country
            end
          DUMMY_CITY_INDEX
        end.to raise_error(/Index scope is already defined/)

        expect do
          Kernel.eval <<-DUMMY_CITY_INDEX
            class DummyCityIndex2 < Chewy::Index
              index_scope City::Nothing
            end
          DUMMY_CITY_INDEX
        end.to raise_error(NameError)
      end
    end
  end

  describe '.settings' do
    before do
      allow(Chewy).to receive_messages(config: Chewy::Config.send(:new))

      Chewy.analyzer :name, filter: %w[lowercase icu_folding names_nysiis]
      Chewy.analyzer :phone, tokenizer: 'ngram', char_filter: ['phone']
      Chewy.tokenizer :ngram, type: 'nGram', min_gram: 3, max_gram: 3
      Chewy.char_filter :phone, type: 'pattern_replace', pattern: '[^\d]', replacement: ''
      Chewy.filter :names_nysiis, type: 'phonetic', encoder: 'nysiis', replace: false
    end

    let(:documents) do
      stub_index(:documents) do
        settings analysis: {analyzer: [:name, :phone, {sorted: {option: :baz}}]}
      end
    end

    specify { expect { documents.settings_hash }.to_not change(documents._settings, :inspect) }
    specify do
      expect(documents.settings_hash).to eq(settings: {analysis: {
        analyzer: {name: {filter: %w[lowercase icu_folding names_nysiis]},
                   phone: {tokenizer: 'ngram', char_filter: ['phone']},
                   sorted: {option: :baz}},
        tokenizer: {ngram: {type: 'nGram', min_gram: 3, max_gram: 3}},
        char_filter: {phone: {type: 'pattern_replace', pattern: '[^\d]', replacement: ''}},
        filter: {names_nysiis: {type: 'phonetic', encoder: 'nysiis', replace: false}}
      }})
    end
  end

  describe '.scopes' do
    before do
      stub_index(:places) do
        def self.by_rating; end

        def self.colors(*colors)
          filter(terms: {colors: colors.flatten(1).map(&:to_s)})
        end

        def self.by_id; end
        field :colors
      end
    end

    specify { expect(described_class.scopes).to eq([]) }
    specify { expect(PlacesIndex.scopes).to match_array(%i[by_rating colors by_id]) }

    context do
      before do
        drop_indices
        PlacesIndex.import!(
          double(colors: ['red']),
          double(colors: %w[red green]),
          double(colors: %w[green yellow])
        )
      end

      specify do
        expect(PlacesIndex.colors(:green).map(&:colors))
          .to contain_exactly(%w[red green], %w[green yellow])
      end

      specify do
        expect(PlacesIndex.colors(:green).map(&:colors))
          .to contain_exactly(%w[red green], %w[green yellow])
      end
    end
  end

  describe '.settings_hash' do
    before { allow(Chewy).to receive_messages(config: Chewy::Config.send(:new)) }

    specify { expect(stub_index(:documents).settings_hash).to eq({}) }
    specify do
      expect(stub_index(:documents) do
               settings number_of_shards: 1
             end.settings_hash).to eq(settings: {number_of_shards: 1})
    end
  end

  describe '.mappings_hash' do
    specify { expect(stub_index(:documents).mappings_hash).to eq({}) }
    specify { expect(stub_index(:documents) { index_scope :document }.mappings_hash).to eq({}) }
    specify do
      expect(stub_index(:documents) do
               field :date, type: 'date'
             end.mappings_hash).to eq(mappings: {properties: {date: {type: 'date'}}})
    end
  end

  describe '.specification_hash' do
    before { allow(Chewy).to receive_messages(config: Chewy::Config.send(:new)) }

    specify { expect(stub_index(:documents).specification_hash).to eq({}) }
    specify do
      expect(stub_index(:documents) do
               settings number_of_shards: 1
             end.specification_hash.keys).to eq([:settings])
    end
    specify do
      expect(stub_index(:documents) do
               field :name
             end.specification_hash.keys).to eq([:mappings])
    end
    specify do
      expect(stub_index(:documents) do
               settings number_of_shards: 1
               field :name
             end.specification_hash.keys).to match_array(%i[mappings settings])
    end
  end

  describe '.specification' do
    subject { stub_index(:documents) }
    specify { expect(subject.specification).to be_a(Chewy::Index::Specification) }
    specify { expect(subject.specification).to equal(subject.specification) }
  end

  context 'index call inside index', :orm do
    before do
      stub_index(:cities) do
        field :country_name, value: (lambda do |city|
          CountriesIndex.filter(term: {_id: city.country_id}).first.name
        end)
      end

      stub_index(:countries) do
        field :name
      end

      CountriesIndex.import!(double(id: 1, name: 'Country'))
    end

    specify do
      expect { CitiesIndex.import!(double(country_id: 1)) }
        .to update_index(CitiesIndex).and_reindex(country_name: 'Country')
    end
  end
end

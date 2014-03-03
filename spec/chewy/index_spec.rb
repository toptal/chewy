require 'spec_helper'

describe Chewy::Index do
  include ClassHelpers

  before do
    stub_index(:dummies) do
      define_type :dummy
    end
  end

  describe '.client' do
    specify { stub_index(:dummies1).client.should == stub_index(:dummies2).client }

    context do
      before do
        stub_index(:dummies1)
        stub_index(:dummies2, Dummies1Index)
      end

      specify { Dummies1Index.client.should == Dummies2Index.client }
    end
  end

  describe '.settings' do
    before do
      Chewy.stub(config: Chewy::Config.send(:new))

      Chewy.analyzer :name, filter: ['lowercase', 'icu_folding', 'names_nysiis']
      Chewy.analyzer :phone, tokenizer: 'ngram', char_filter: ['phone']
      Chewy.tokenizer :ngram, type: 'nGram', min_gram: 3, max_gram: 3
      Chewy.char_filter :phone, type: 'pattern_replace', pattern: '[^\d]', replacement: ''
      Chewy.filter :names_nysiis, type: 'phonetic', encoder: 'nysiis', replace: false
    end

    let(:documents) { stub_index(:documents) { settings analysis: {analyzer: [:name, :phone, {sorted: {option: :baz}}]} } }

    specify { expect { documents.settings_hash }.to_not change(documents._settings, :inspect)  }
    specify { documents.settings_hash.should == {settings: {analysis: {
      analyzer: {name: {filter: ['lowercase', 'icu_folding', 'names_nysiis']},
                 phone: {tokenizer: 'ngram', char_filter: ['phone']},
                 sorted: {option: :baz}},
      tokenizer: {ngram: {type: 'nGram', min_gram: 3, max_gram: 3}},
      char_filter: {phone: {type: 'pattern_replace', pattern: '[^\d]', replacement: ''}},
      filter: {names_nysiis: {type: 'phonetic', encoder: 'nysiis', replace: false}}
    }}} }
  end

  describe '.define_type' do
    specify { DummiesIndex.type_hash['dummy'].should == DummiesIndex::Dummy }

    context do
      before { stub_index(:dummies) { define_type :dummy, name: :borogoves } }
      specify { DummiesIndex.type_hash['borogoves'].should == DummiesIndex::Borogoves }
    end

    context do
      before { stub_model(:city) }
      before { stub_index(:dummies) { define_type City, name: :country } }
      specify { DummiesIndex.type_hash['country'].should == DummiesIndex::Country }
    end
  end

  describe '.type_hash' do
    specify { DummiesIndex.type_hash['dummy'].should == DummiesIndex::Dummy }
    specify { DummiesIndex.type_hash.should have_key 'dummy' }
    specify { DummiesIndex.type_hash['dummy'].should be < Chewy::Type::Base }
    specify { DummiesIndex.type_hash['dummy'].type_name.should == 'dummy' }
  end

  specify { DummiesIndex.type_names.should == DummiesIndex.type_hash.keys }

  describe '.types' do
    specify { DummiesIndex.types.should == DummiesIndex.type_hash.values }
    specify { DummiesIndex.types(:dummy).should be_a Chewy::Query }
    specify { DummiesIndex.types(:user).should be_a Chewy::Query }
  end

  describe '.index_name' do
    specify { expect { Class.new(Chewy::Index).index_name }.to raise_error Chewy::UndefinedIndex }
    specify { Class.new(Chewy::Index) { index_name :myindex }.index_name.should == 'myindex' }
    specify { stub_const('DeveloperIndex', Class.new(Chewy::Index)).index_name.should == 'developer' }
    specify { stub_const('DevelopersIndex', Class.new(Chewy::Index)).index_name.should == 'developers' }

    context do
      before { Chewy.stub(configuration: {prefix: 'testing'}) }
      specify { DummiesIndex.index_name.should == 'testing_dummies' }
      specify { stub_index(:dummies) { index_name :users }.index_name.should == 'testing_users' }
    end
  end

  describe '.build_index_name' do
    specify { stub_const('DevelopersIndex', Class.new(Chewy::Index)).build_index_name(suffix: '').should == 'developers' }
    specify { stub_const('DevelopersIndex', Class.new(Chewy::Index)).build_index_name(suffix: '2013').should == 'developers_2013' }
    specify { stub_const('DevelopersIndex', Class.new(Chewy::Index)).build_index_name(prefix: '').should == 'developers' }
    specify { stub_const('DevelopersIndex', Class.new(Chewy::Index)).build_index_name(prefix: 'test').should == 'test_developers' }
    specify { stub_const('DevelopersIndex', Class.new(Chewy::Index)).build_index_name(:users, prefix: 'test', suffix: '2013').should == 'test_users_2013' }
  end

  describe '.index_params' do
    before { Chewy.stub(config: Chewy::Config.send(:new)) }

    specify { stub_index(:documents).index_params.should == {} }
    specify { stub_index(:documents) { settings number_of_shards: 1 }.index_params.keys.should == [:settings] }
    specify { stub_index(:documents) do
      define_type :document do
        field :name, type: 'string'
      end
    end.index_params.keys.should == [:mappings] }
    specify { stub_index(:documents) do
      settings number_of_shards: 1
      define_type :document do
        field :name, type: 'string'
      end
    end.index_params.keys.should =~ [:mappings, :settings] }
  end

  describe '.settings_hash' do
    before { Chewy.stub(config: Chewy::Config.send(:new)) }

    specify { stub_index(:documents).settings_hash.should == {} }
    specify { stub_index(:documents) { settings number_of_shards: 1 }.settings_hash.should == {settings: {number_of_shards: 1}} }
  end

  describe '.mappings_hash' do
    specify { stub_index(:documents).mappings_hash.should == {} }
    specify { stub_index(:documents) { define_type :document }.mappings_hash.should == {} }
    specify { stub_index(:documents) do
      define_type :document do
        field :name, type: 'string'
      end
    end.mappings_hash.should == {mappings: {document: {properties: {name: {type: 'string'}}}}} }
    specify { stub_index(:documents) do
      define_type :document do
        field :name, type: 'string'
      end
      define_type :document2 do
        field :name, type: 'string'
      end
    end.mappings_hash[:mappings].keys.should =~ [:document, :document2] }
  end

  describe '.import' do
    before do
      stub_model(:city)
      stub_model(:country)

      stub_index(:places) do
        define_type City
        define_type Country
      end
    end

    let!(:cities) { 2.times.map { City.create! } }
    let!(:countries) { 2.times.map { Country.create! } }

    specify do
      expect { PlacesIndex.import }.to update_index(PlacesIndex::City).and_reindex(cities)
      expect { PlacesIndex.import }.to update_index(PlacesIndex::Country).and_reindex(countries)
    end

    specify do
      expect { PlacesIndex.import city: cities.first }.to update_index(PlacesIndex::City).and_reindex(cities.first).only
      expect { PlacesIndex.import city: cities.first }.to update_index(PlacesIndex::Country).and_reindex(countries)
    end

    specify do
      expect { PlacesIndex.import city: cities.first, country: countries.last }.to update_index(PlacesIndex::City).and_reindex(cities.first).only
      expect { PlacesIndex.import city: cities.first, country: countries.last }.to update_index(PlacesIndex::Country).and_reindex(countries.last).only
    end

    specify do
      expect(PlacesIndex.client).to receive(:bulk).with(hash_including(refresh: false)).twice
      PlacesIndex.import city: cities.first, refresh: false
    end
  end
end

require 'spec_helper'

describe Chewy::Index do
  include ClassHelpers

  describe '.define_type' do
    context 'blank name' do
      before do
        stub_index(:dummies) do
          define_type :dummy
        end
      end

      specify { DummiesIndex.types.should == DummiesIndex.type_hash.values }
      specify { DummiesIndex.type_names.should == DummiesIndex.type_hash.keys }
      specify { DummiesIndex.type_hash['dummy'].should == DummiesIndex::Dummy }
      specify { DummiesIndex.type_hash.should have_key 'dummy' }
      specify { DummiesIndex.type_hash['dummy'].should be < Chewy::Type::Base }
      specify { DummiesIndex.type_hash['dummy'].type_name.should == 'dummy' }
    end
  end

  describe '.index_name' do
    specify { expect { Class.new(Chewy::Index).index_name }.to raise_error Chewy::UndefinedIndex }
    specify { Class.new(Chewy::Index) { index_name :myindex }.index_name.should == 'myindex' }
    specify { stub_const('DeveloperIndex', Class.new(Chewy::Index)).index_name.should == 'developer' }
    specify { stub_const('DevelopersIndex', Class.new(Chewy::Index)).index_name.should == 'developers' }
  end

  describe '.index_params' do
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
end

require 'spec_helper'

describe Chewy::Index do
  include ClassHelpers

  describe '.define_type' do
    context 'existing' do
      let!(:dummy_type) { stub_const('DummyType', type_class) }
      let(:dummy_index) do
        index_class do
          index_name :dummy_index
          define_type DummyType
        end
      end

      specify { dummy_index.types.should have_key 'dummy_type' }
      specify { dummy_index.types['dummy_type'].should == DummyType }
      specify { dummy_index.dummy_type.should == DummyType }
    end

    context 'block' do
      context 'blank name' do
        let(:dummy_index) do
          index_class do
            index_name :dummy_index
            define_type {}
          end
        end

        specify { dummy_index.types.should have_key 'dummy_index' }
        specify { dummy_index.types['dummy_index'].should be < Chewy::Type }
        specify { dummy_index.types['dummy_index'].type_name.should == 'dummy_index' }
      end

      context 'given name' do
        let(:dummy_index) do
          index_class do
            index_name :dummy_index
            define_type(:dummy_type) {}
          end
        end

        specify { dummy_index.types.should have_key 'dummy_type' }
        specify { dummy_index.types['dummy_type'].should be < Chewy::Type }
        specify { dummy_index.types['dummy_type'].type_name.should == 'dummy_type' }
      end
    end
  end

  describe '.index_name' do
    specify { expect { index_class.index_name }.to raise_error Chewy::UndefinedIndex }
    specify { index_class { index_name :myindex }.index_name.should == 'myindex' }
    specify { stub_const('DeveloperIndex', index_class).index_name.should == 'developer' }
    specify { stub_const('DevelopersIndex', index_class).index_name.should == 'developers' }
  end

  describe '.index_params' do
    specify { index_class.index_params.should == {} }
    specify { index_class { settings number_of_shards: 1 }.index_params.keys.should == [:settings] }
    specify { index_class(:documents) do
      define_type do
        root do
          field :name, type: 'string'
        end
      end
    end.index_params.keys.should == [:mappings] }
    specify { index_class(:documents) do
      settings number_of_shards: 1
      define_type do
        root do
          field :name, type: 'string'
        end
      end
    end.index_params.keys.should =~ [:mappings, :settings] }
  end

  describe '.settings_hash' do
    specify { index_class.settings_hash.should == {} }
    specify { index_class { settings number_of_shards: 1 }.settings_hash.should == {settings: {number_of_shards: 1}} }
  end

  describe '.mappings_hash' do
    specify { index_class.mappings_hash.should == {} }
    specify { index_class(:documents) { define_type {} }.mappings_hash.should == {} }
    specify { index_class(:documents) do
      define_type do
        root do
          field :name, type: 'string'
        end
      end
    end.mappings_hash.should == {mappings: {document: {properties: {name: {type: 'string'}}}}} }
    specify { index_class(:documents) do
      define_type do
        root do
          field :name, type: 'string'
        end
      end
      define_type(:document2) do
        root do
          field :name, type: 'string'
        end
      end
    end.mappings_hash[:mappings].keys.should =~ [:document, :document2] }
  end
end

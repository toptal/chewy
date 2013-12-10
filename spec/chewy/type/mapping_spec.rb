require 'spec_helper'

describe Chewy::Type::Mapping do
  include ClassHelpers

  let(:dummy_type) do
    Class.new(Chewy::Type) do
      type_name :product
      root do
        field :name, 'surname'
        field :title, type: 'string' do
          field :subfield1
        end
        field 'price', type: 'float' do
          field :subfield2
        end
      end
    end
  end

  describe '.field' do
    specify { dummy_type.root_object.nested.keys.should =~ [:name, :surname, :title, :price] }
    specify { dummy_type.root_object.nested.values.should satisfy { |v| v.all? { |f| f.is_a? Chewy::Fields::Default } } }

    specify { dummy_type.root_object.nested[:title].nested.keys.should == [:subfield1] }
    specify { dummy_type.root_object.nested[:title].nested[:subfield1].should be_a Chewy::Fields::Default }

    specify { dummy_type.root_object.nested[:price].nested.keys.should == [:subfield2] }
    specify { dummy_type.root_object.nested[:price].nested[:subfield2].should be_a Chewy::Fields::Default }
  end

  describe '.mappings_hash' do
    specify { Class.new(Chewy::Type).mappings_hash.should == {} }
    specify { dummy_type.mappings_hash.should == dummy_type.root_object.mappings_hash }
  end

  context "no root element call" do
    let(:dummy_type) do
      Class.new(Chewy::Type) do
        type_name :product
        field :title, type: 'string' do
          field :subfield1
        end
      end
    end

    specify { dummy_type.root_object.nested[:title].nested.keys.should == [:subfield1] }
    specify { dummy_type.root_object.nested[:title].nested[:subfield1].should be_a Chewy::Fields::Default }
  end
end

require 'spec_helper'

describe Chewy::Type::Mapping do
  let(:product) { ProductsIndex::Product }

  before do
    stub_index(:products) do
      define_type :product do
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
  end

  describe '.field' do
    specify { expect(product.root_object.nested.keys).to match_array([:name, :surname, :title, :price]) }
    specify { expect(product.root_object.nested.values).to satisfy { |v| v.all? { |f| f.is_a? Chewy::Fields::Base } } }

    specify { expect(product.root_object.nested[:title].nested.keys).to eq([:subfield1]) }
    specify { expect(product.root_object.nested[:title].nested[:subfield1]).to be_a Chewy::Fields::Base }

    specify { expect(product.root_object.nested[:price].nested.keys).to eq([:subfield2]) }
    specify { expect(product.root_object.nested[:price].nested[:subfield2]).to be_a Chewy::Fields::Base }
  end

  describe '.mappings_hash' do
    specify { expect(Class.new(Chewy::Type).mappings_hash).to eq({}) }
    specify { expect(product.mappings_hash).to eq(product.root_object.mappings_hash) }

    context 'parent-child relationship' do
      context do
        before do
          stub_index(:products) do
            define_type :product do
              root _parent: 'project', parent_id: -> { project_id } do
                field :name, 'surname'
              end
            end
          end
        end

        specify { expect(product.mappings_hash[:product][:_parent]).to eq({ type: 'project' }) }
      end

      context do
        before do
          stub_index(:products) do
            define_type :product do
              root parent: {'type' => 'project'}, parent_id: -> { project_id } do
                field :name, 'surname'
              end
            end
          end
        end

        specify { expect(product.mappings_hash[:product][:_parent]).to eq({ 'type' => 'project' }) }
      end
    end
  end

  context "no root element call" do
    before do
      stub_index(:products) do
        define_type :product do
          field :title, type: 'string' do
            field :subfield1
          end
        end
      end
    end

    specify { expect(product.root_object.nested[:title].nested.keys).to eq([:subfield1]) }
    specify { expect(product.root_object.nested[:title].nested[:subfield1]).to be_a Chewy::Fields::Base }
  end
end

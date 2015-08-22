require 'spec_helper'

describe Chewy::Type::Mapping do
  let(:product) { ProductsIndex::Product }
  let(:review)  { ProductsIndex::Review }

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
          agg :named_agg do
            { avg: { field: 'title.subfield1' } }
          end
        end
      end
      define_type :review do
        field :title, :body
        field :comments do
          field :message
          field :rating, type: 'long'
        end
        agg :named_agg do
          { avg: { field: 'comments.rating' } }
        end
      end
    end
  end

  describe '.agg' do
    specify { expect(product.agg_defs[:named_agg].call).to eq({ avg: { field: 'title.subfield1' } }) }
    specify { expect(review.agg_defs[:named_agg].call).to eq({ avg: { field: 'comments.rating' } }) }
  end

  describe '.field' do
    specify { expect(product.root_object.children.map(&:name)).to eq([:name, :surname, :title, :price]) }
    specify { expect(product.root_object.children.map(&:parent)).to eq([product.root_object] * 4) }

    specify { expect(product.root_object.children[0].children.map(&:name)).to eq([]) }
    specify { expect(product.root_object.children[1].children.map(&:name)).to eq([]) }

    specify { expect(product.root_object.children[2].children.map(&:name)).to eq([:subfield1]) }
    specify { expect(product.root_object.children[2].children.map(&:parent)).to eq([product.root_object.children[2]]) }

    specify { expect(product.root_object.children[3].children.map(&:name)).to eq([:subfield2]) }
    specify { expect(product.root_object.children[3].children.map(&:parent)).to eq([product.root_object.children[3]]) }
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

        specify { expect(product.mappings_hash[:product][:_parent]).to eq({ type: 'project' }) }
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

    specify { expect(product.root_object.children.map(&:name)).to eq([:title]) }
    specify { expect(product.root_object.children.map(&:parent)).to eq([product.root_object]) }
    specify { expect(product.root_object.children[0].children.map(&:name)).to eq([:subfield1]) }
    specify { expect(product.root_object.children[0].children.map(&:parent)).to eq([product.root_object.children[0]]) }
  end
end

require 'spec_helper'

describe Chewy::Type::Mapping do
  let(:product) { ProductsIndex::Product }
  let(:review)  { ReviewsIndex::Review }

  before do
    stub_index(:products) do
      define_type :product do
        root do
          field :name, 'surname'
          field :title, type: 'text' do
            field :subfield1
          end
          field 'price', type: 'float' do
            field :subfield2
          end
          agg :named_agg do
            {avg: {field: 'title.subfield1'}}
          end
        end
      end
    end
    stub_index(:reviews) do
      define_type :review do
        field :title, :body
        field :comments do
          field :message
          field :rating, type: 'long'
        end
        agg :named_agg do
          {avg: {field: 'comments.rating'}}
        end
      end
    end
  end

  context 'no root element call' do
    before do
      stub_index(:products) do
        define_type :product do
          field :title, type: 'text' do
            field :subfield1
          end
        end
      end
    end

    specify { expect(product.root.children.map(&:name)).to eq([:title]) }
    specify { expect(product.root.children.map(&:parent)).to eq([product.root]) }
    specify { expect(product.root.children[0].children.map(&:name)).to eq([:subfield1]) }
    specify { expect(product.root.children[0].children.map(&:parent)).to eq([product.root.children[0]]) }

    context 'default root options are set' do
      around do |example|
        previous_options = Chewy.default_root_options
        Chewy.default_root_options = {_all: {enabled: false}}
        example.run
        Chewy.default_root_options = previous_options
      end

      specify { expect(product.mappings_hash[:product]).to include(_all: {enabled: false}) }
    end
  end

  describe '.agg' do
    specify { expect(product._agg_defs[:named_agg].call).to eq(avg: {field: 'title.subfield1'}) }
    specify { expect(review._agg_defs[:named_agg].call).to eq(avg: {field: 'comments.rating'}) }
  end

  describe '.field' do
    specify { expect(product.root.children.map(&:name)).to eq(%i[name surname title price]) }
    specify { expect(product.root.children.map(&:parent)).to eq([product.root] * 4) }

    specify { expect(product.root.children[0].children.map(&:name)).to eq([]) }
    specify { expect(product.root.children[1].children.map(&:name)).to eq([]) }

    specify { expect(product.root.children[2].children.map(&:name)).to eq([:subfield1]) }
    specify { expect(product.root.children[2].children.map(&:parent)).to eq([product.root.children[2]]) }

    specify { expect(product.root.children[3].children.map(&:name)).to eq([:subfield2]) }
    specify { expect(product.root.children[3].children.map(&:parent)).to eq([product.root.children[3]]) }
  end

  describe '.mappings_hash' do
    specify { expect(product.mappings_hash).to eq(product.root.mappings_hash) }

    context 'root merging' do
      context do
        before do
          stub_index(:products) do
            define_type :product do
              root other_option: 'nothing' do
                field :name do
                  field :last_name # will be redefined in the following root flock
                end
              end
              root other_option: 'option_value' do
                field :identifier
                field :name, type: 'integer'
              end
            end
          end
        end

        specify do
          expect(product.mappings_hash).to eq(product: {
            properties: {
              name: {type: 'integer'},
              identifier: {type: Chewy.default_field_type}
            },
            other_option: 'option_value',
          })
        end
      end
    end
  end

  describe '.supports_outdated_sync?' do
    def type(&block)
      stub_index(:cities) do
        define_type :city, &block
      end
      CitiesIndex::City
    end

    specify { expect(type.supports_outdated_sync?).to eq(false) }
    specify { expect(type { field :updated_at }.supports_outdated_sync?).to eq(true) }
    specify { expect(type { field :updated_at, value: -> {} }.supports_outdated_sync?).to eq(false) }
    specify do
      expect(type do
        self.outdated_sync_field = :version
        field :updated_at
      end.supports_outdated_sync?).to eq(false)
    end
    specify do
      expect(type do
        self.outdated_sync_field = :version
        field :version
      end.supports_outdated_sync?).to eq(true)
    end
  end
end

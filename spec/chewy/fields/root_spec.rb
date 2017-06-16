require 'spec_helper'

describe Chewy::Fields::Root do
  subject(:field) { described_class.new('product') }

  describe '#dynamic_template' do
    specify do
      field.dynamic_template 'hello', type: 'string'
      field.dynamic_template 'hello*', :integer
      field.dynamic_template 'hello.*'
      field.dynamic_template(/hello/)
      field.dynamic_template(/hello.*/)
      field.dynamic_template template_42: {mapping: {}, match: ''}
      field.dynamic_template(/hello\..*/)

      expect(field.mappings_hash).to eq(product: {dynamic_templates: [
        {template_1: {mapping: {type: 'string'}, match: 'hello'}},
        {template_2: {mapping: {}, match_mapping_type: 'integer', match: 'hello*'}},
        {template_3: {mapping: {}, path_match: 'hello.*'}},
        {template_4: {mapping: {}, match: 'hello', match_pattern: 'regexp'}},
        {template_5: {mapping: {}, match: 'hello.*', match_pattern: 'regexp'}},
        {template_42: {mapping: {}, match: ''}},
        {template_7: {mapping: {}, path_match: 'hello\..*', match_pattern: 'regexp'}}
      ]})
    end

    context do
      subject(:field) do
        described_class.new('product', dynamic_templates: [
          {template_42: {mapping: {}, match: ''}}
        ])
      end

      specify do
        field.dynamic_template 'hello', type: 'string'
        expect(field.mappings_hash).to eq(product: {dynamic_templates: [
          {template_42: {mapping: {}, match: ''}},
          {template_1: {mapping: {type: 'string'}, match: 'hello'}}
        ]})
      end
    end
  end

  describe '#compose' do
    context 'empty children', :orm do
      before do
        stub_model(:city)
        stub_index(:places) do
          define_type City
        end
      end

      let(:city) { City.new(name: 'London', rating: 100) }

      specify do
        expect(PlacesIndex::City.send(:build_root).compose(city))
          .to match(hash_including('name' => 'London', 'rating' => 100))
      end
      specify do
        expect(PlacesIndex::City.send(:build_root).compose(city, fields: %i[name borogoves]))
          .to eq('name' => 'London')
      end
    end

    context 'has children' do
      before do
        stub_index(:places) do
          define_type :city do
            field :name, :rating
          end
        end
      end

      let(:city) { double(name: 'London', rating: 100) }

      specify do
        expect(PlacesIndex::City.send(:build_root).compose(city))
          .to eq('name' => 'London', 'rating' => 100)
      end
      specify do
        expect(PlacesIndex::City.send(:build_root).compose(city, fields: %i[name borogoves]))
          .to eq('name' => 'London')
      end
    end
  end
end

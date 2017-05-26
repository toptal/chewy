require 'spec_helper'

describe Chewy::Type do
  describe '.full_name' do
    before do
      stub_index(:places) do
        define_type :city
      end
    end

    specify { expect(PlacesIndex::City.full_name).to eq('places#city') }
  end

  describe '.scopes' do
    before do
      stub_index(:places) do
        def self.by_id; end

        define_type :city do
          def self.by_rating; end

          def self.by_name; end
        end
      end
    end

    specify { expect(described_class.scopes).to eq([]) }
    specify { expect(PlacesIndex::City.scopes).to match_array(%i[by_rating by_name]) }
    specify { expect { PlacesIndex::City.non_existing_method_call }.to raise_error(NoMethodError) }

    specify { expect(PlacesIndex::City._default_import_options).to eq({}) }
    specify { expect { PlacesIndex::City.default_import_options(invalid_option: 'Yeah!') }.to raise_error(ArgumentError) }

    context 'default_import_options is set' do
      let(:converter) { -> {} }
      before { PlacesIndex::City.default_import_options(batch_size: 500, raw_import: converter) }

      specify { expect(PlacesIndex::City._default_import_options).to eq(batch_size: 500, raw_import: converter) }
    end
  end
end

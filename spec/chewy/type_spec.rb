require 'spec_helper'

describe Chewy::Type do
  describe '.scopes' do
    before do
      stub_index(:places) do
        def self.by_id
        end

        define_type :city do
          def self.by_rating
          end

          def self.by_name
          end
        end
      end
    end

    specify { expect(described_class.scopes).to eq([]) }
    specify { expect(PlacesIndex::City._default_import_options).to eq({}) }
    specify { expect(PlacesIndex::City.scopes).to match_array([:by_rating, :by_name]) }
    specify { expect { PlacesIndex::City.non_existing_method_call }.to raise_error(NoMethodError) }

    context 'default_import_options is set' do
      before { PlacesIndex::City.default_import_options(batch_size: 500) }

      specify { expect(PlacesIndex::City._default_import_options).to eq(batch_size: 500) }
    end
  end
end

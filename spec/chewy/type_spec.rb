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
    specify { expect(PlacesIndex::City.scopes).to match_array([:by_rating, :by_name]) }
  end
end

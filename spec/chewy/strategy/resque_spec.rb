require 'spec_helper'

if defined?(::Resque)
  require 'resque_spec'

  describe Chewy::Strategy::Resque do
    around { |example| Chewy.strategy(:bypass) { example.run } }
    before { ResqueSpec.reset! }
    before do
      stub_model(:city) do
        update_index('cities#city') { self }
      end

      stub_index(:cities) do
        define_type City
      end
    end

    let(:city) { City.create!(name: 'hello') }
    let(:other_city) { City.create!(name: 'world') }

    specify do
      expect { [city, other_city].map(&:save!) }
        .not_to update_index(CitiesIndex::City, strategy: :resque)
    end

    specify do
      with_resque do
        expect { [city, other_city].map(&:save!) }
          .to update_index(CitiesIndex::City, strategy: :resque)
          .and_reindex(city, other_city)
      end
    end
  end
end

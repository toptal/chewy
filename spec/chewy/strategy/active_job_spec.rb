require 'spec_helper'

if defined?(::ActiveJob)
  describe Chewy::Strategy::ActiveJob do
    around { |example| Chewy.strategy(:bypass) { example.run } }
    before do
      ::ActiveJob::Base.queue_adapter = :test
      ::ActiveJob::Base.queue_adapter.enqueued_jobs.clear
      ::ActiveJob::Base.queue_adapter.performed_jobs.clear
    end

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
        .not_to update_index(CitiesIndex::City, strategy: :active_job)
    end

    specify do
      ::ActiveJob::Base.queue_adapter = :inline
      expect { [city, other_city].map(&:save!) }
        .to update_index(CitiesIndex::City, strategy: :active_job)
        .and_reindex(city, other_city)
    end
  end
end

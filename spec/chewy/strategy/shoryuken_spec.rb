require 'spec_helper'

if defined?(::Shoryuken)

  describe Chewy::Strategy::Shoryuken do
    around { |example| Chewy.strategy(:bypass) { example.run } }
    before { ::Shoryuken.queues.clear }
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
    let(:queue) { instance_double(::Shoryuken::Queue) }

    before do
      allow(::Shoryuken::Queue).to receive(:new).and_return(queue)
      allow(queue).to receive(:send_message).and_return(nil)
    end

    specify do
      expect { [city, other_city].map(&:save!) }
        .not_to update_index(CitiesIndex::City, strategy: :shoryuken)
    end

    specify do
      Chewy.settings[:shoryuken] = {queue: 'low'}
      expect(Chewy::Strategy::Shoryuken::Worker).to receive(:perform_async)
        .with(hash_including(index: CitiesIndex::City, ids: [city.id, other_city.id]), hash_including(queue: 'low'))
      Chewy.strategy(:shoryuken) do
        [city, other_city].map(&:save!)
      end
    end

    let(:body) { { 'index' => 'CitiesIndex::City', 'ids' => [city.id, other_city.id] } }
    let(:sqs_msg) { double id: 'fc754df7-9cc2-4c41-96ca-5996a44b771e',
                           body: body,
                           delete: nil }

    specify do
      expect(CitiesIndex::City).to receive(:import!).with([city.id, other_city.id], suffix: '201601')
      Chewy::Strategy::Shoryuken::Worker.new.perform(sqs_msg, body, suffix: '201601')
    end

    specify do
      allow(Chewy).to receive(:disable_refresh_async).and_return(true)
      expect(CitiesIndex::City).to receive(:import!).with([city.id, other_city.id], suffix: '201601', refresh: false)
      Chewy::Strategy::Shoryuken::Worker.new.perform(sqs_msg, body, suffix: '201601')
    end
  end
end

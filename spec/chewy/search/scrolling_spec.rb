require 'spec_helper'

describe Chewy::Search::Scrolling, :orm do
  before { Chewy.massacre }

  before do
    stub_model(:city)
    stub_model(:country)

    stub_index(:cities) do
      index_scope City
      field :name
      field :rating, type: 'integer'
    end
    stub_index(:countries) do
      index_scope Country
      field :name
      field :rating, type: 'integer'
    end
  end

  let(:request) { Chewy::Search::Request.new(CitiesIndex, CountriesIndex).order(:rating) }

  specify { expect(request.scroll_batches.to_a).to eq([]) }

  context do
    before do
      CitiesIndex.import!(cities)
      CountriesIndex.import!(countries: countries)
    end

    let(:cities) { Array.new(2) { |i| City.create!(rating: i, name: "city #{i}") } }
    let(:countries) { Array.new(3) { |i| Country.create!(rating: i + 2, name: "country #{i}") } }

    describe '#scroll_batches' do
      describe 'with search backend returning failures' do
        before do
          expect(Chewy.client).to receive(:scroll).once.and_return(
            'hits' => {
              'total' => {
                'value' => 5
              },
              'hits' => []
            },
            '_shards' => {
              'total' => 5,
              'successful' => 2,
              'skipped' => 0,
              'failed' => 3,
              'failures' => [
                {
                  'shard' => -1,
                  'index' => nil,
                  'reason' => {
                    'type' => 'search_context_missing_exception',
                    'reason' => 'No search context found for id [34462229]'
                  }
                },
                {
                  'shard' => -1,
                  'index' => nil,
                  'reason' => {
                    'type' => 'search_context_missing_exception',
                    'reason' => 'No search context found for id [34462228]'
                  }
                },
                {
                  'shard' => -1,
                  'index' => nil,
                  'reason' => {
                    'type' => 'search_context_missing_exception',
                    'reason' => 'No search context found for id [34888662]'
                  }
                }
              ]
            },
            '_scroll_id' => 'scroll_id'
          )
        end

        specify do
          expect { request.scroll_batches(batch_size: 2) {} }.to raise_error(Chewy::MissingHitsInScrollError)
        end
      end

      context do
        before { expect(Chewy.client).to receive(:scroll).twice.and_call_original }
        specify do
          expect(request.scroll_batches(batch_size: 2).map do |batch|
            batch.map { |hit| hit['_source']['rating'] }
          end).to eq([[0, 1], [2, 3], [4]])
        end
      end

      context do
        before { expect(Chewy.client).to receive(:scroll).once.and_call_original }
        specify do
          expect(request.scroll_batches(batch_size: 3).map do |batch|
            batch.map { |hit| hit['_source']['rating'] }
          end).to eq([[0, 1, 2], [3, 4]])
        end
      end

      context do
        before { expect(Chewy.client).to receive(:scroll).once.and_call_original }
        it 'respects limit' do
          expect(request.limit(4).scroll_batches(batch_size: 3).map do |batch|
            batch.map { |hit| hit['_source']['rating'] }
          end).to eq([[0, 1, 2], [3]])
        end
      end

      context do
        before { expect(Chewy.client).not_to receive(:scroll) }
        it 'respects limit and terminate_after' do
          expect(request.terminate_after(1).limit(4).scroll_batches(batch_size: 3).map do |batch|
            batch.map { |hit| hit['_source']['rating'] }
          end).to eq([[0, 2]])
        end
      end

      context do
        before { expect(Chewy.client).not_to receive(:scroll) }
        it 'respects limit' do
          expect(request.limit(3).scroll_batches(batch_size: 3).map do |batch|
            batch.map { |hit| hit['_source']['rating'] }
          end).to eq([[0, 1, 2]])
        end
      end

      context do
        before { expect(Chewy.client).not_to receive(:scroll) }
        it 'respects limit' do
          expect(request.limit(2).scroll_batches(batch_size: 3).map do |batch|
            batch.map { |hit| hit['_source']['rating'] }
          end).to eq([[0, 1]])
        end
      end

      context do
        before { expect(Chewy.client).not_to receive(:scroll) }
        specify do
          expect(request.scroll_batches(batch_size: 5).map do |batch|
            batch.map { |hit| hit['_source']['rating'] }
          end).to eq([[0, 1, 2, 3, 4]])
        end
      end

      context do
        before { expect(Chewy.client).not_to receive(:scroll) }
        specify do
          expect(request.scroll_batches(batch_size: 10).map do |batch|
            batch.map { |hit| hit['_source']['rating'] }
          end).to eq([[0, 1, 2, 3, 4]])
        end
      end

      it 'clears the scroll after completion' do
        expect(Chewy.client).to receive(:clear_scroll).with(body: {scroll_id: anything}).once.and_call_original
        request.scroll_batches(batch_size: 3) {}
      end

      context 'instrumentation' do
        specify do
          outer_payload = []
          ActiveSupport::Notifications.subscribe('search_query.chewy') do |_name, _start, _finish, _id, payload|
            outer_payload << payload
          end
          request.scroll_batches(batch_size: 3).to_a
          expect(outer_payload).to match_array([
            hash_including(
              index: [CitiesIndex, CountriesIndex],
              indexes: [CitiesIndex, CountriesIndex],
              request: {index: %w[cities countries], body: {sort: ['rating']}, size: 3, scroll: '1m'}
            ),
            hash_including(
              index: [CitiesIndex, CountriesIndex],
              indexes: [CitiesIndex, CountriesIndex],
              request: {scroll: '1m', scroll_id: an_instance_of(String)}
            )
          ])
        end
      end
    end

    describe '#scroll_hits' do
      before { expect(Chewy.client).to receive(:scroll).twice.and_call_original }
      specify do
        expect(request.scroll_hits(batch_size: 2).map do |hit|
          hit['_source']['rating']
        end).to eq([0, 1, 2, 3, 4])
      end
    end

    describe '#scroll_wrappers' do
      before { expect(Chewy.client).to receive(:scroll).twice.and_call_original }

      specify do
        expect(request.scroll_wrappers(batch_size: 2).map(&:rating))
          .to eq([0, 1, 2, 3, 4])
      end
      specify do
        expect(request.scroll_wrappers(batch_size: 2).map(&:class).uniq)
          .to eq([CitiesIndex, CountriesIndex])
      end
    end

    describe '#scroll_objects' do
      before { expect(Chewy.client).to receive(:scroll).twice.and_call_original }

      specify do
        expect(request.scroll_objects(batch_size: 2).map(&:rating))
          .to eq([0, 1, 2, 3, 4])
      end
      specify do
        expect(request.scroll_objects(batch_size: 2).map(&:class).uniq)
          .to eq([City, Country])
      end
    end
  end
end

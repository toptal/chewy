require 'spec_helper'

describe 'Time fields' do
  before { Chewy.massacre }

  before do
    stub_index(:posts) do
      define_type :post do
        field :published_at, type: 'date'
      end
    end
  end

  before do
    PostsIndex::Post.import(
      double(published_at: ActiveSupport::TimeZone[-28800].parse('2014/12/18 19:00')),
      double(published_at: ActiveSupport::TimeZone[-21600].parse('2014/12/18 20:00')),
      double(published_at: ActiveSupport::TimeZone[-21600].parse('2014/12/17 20:00')),
    )
  end

  let(:time) { ActiveSupport::TimeZone[-14400].parse('2014/12/18 22:00') }
  let(:range) { (time - 1.minute)..(time + 1.minute) }

  specify { expect(PostsIndex.total).to eq(3) }
  specify { expect(PostsIndex.filter { published_at == o { range } }.count).to eq(1) }
  specify { expect(PostsIndex.filter { published_at == o { range.min.utc..(range.max + 1.hour).utc } }.count).to eq(2) }
  specify { expect(PostsIndex.filter { published_at == o { [range.min..range.max] } }.count).to eq(1) }
end

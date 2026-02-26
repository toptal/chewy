# Testing

## RSpec integration

Just add `require 'chewy/rspec'` to your spec_helper.rb and you will get additional features:

[update_index](../lib/chewy/rspec/update_index.rb) helper
`mock_elasticsearch_response` helper to mock elasticsearch response
`mock_elasticsearch_response_sources` helper to mock elasticsearch response sources
`build_query` matcher to compare request and expected query (returns `true`/`false`)

To use `mock_elasticsearch_response` and `mock_elasticsearch_response_sources` helpers add `include Chewy::Rspec::Helpers` to your tests.

See [chewy/rspec/](../lib/chewy/rspec/) for more details.

## Minitest integration

Add `require 'chewy/minitest'` to your test_helper.rb, and then for tests which you'd like indexing test hooks, `include Chewy::Minitest::Helpers`.

You can set the `:bypass` strategy for test suites and manually handle imports and flush test indices using `Chewy.massacre`. This will help reduce unnecessary ES requests.

But if you require chewy to index/update model regularly in your test suite then you can specify `:urgent` strategy for documents indexing. Add `Chewy.strategy(:urgent)` to test_helper.rb.

Also, you can use additional helpers:

`mock_elasticsearch_response` to mock elasticsearch response
`mock_elasticsearch_response_sources` to mock elasticsearch response sources
`assert_elasticsearch_query` to compare request and expected query (returns `true`/`false`)

See [chewy/minitest/](../lib/chewy/minitest/) for more details.

## DatabaseCleaner

If you use `DatabaseCleaner` in your tests with [the `transaction` strategy](https://github.com/DatabaseCleaner/database_cleaner#how-to-use), you may run into the problem that `ActiveRecord`'s models are not indexed automatically on save despite the fact that you set the callbacks to do this with the `update_index` method. The issue arises because `chewy` indices data on `after_commit` run as default, but all `after_commit` callbacks are not run with the `DatabaseCleaner`'s' `transaction` strategy. You can solve this issue by changing the `Chewy.use_after_commit_callbacks` option. Just add the following initializer in your Rails application:

```ruby
#config/initializers/chewy.rb
Chewy.use_after_commit_callbacks = !Rails.env.test?
```

## Testing search results

The `update_index` matcher verifies that index operations are triggered, but
sometimes you need to test that queries return the right documents. Import data
into a real Elasticsearch index and query it:

```ruby
RSpec.describe 'City search' do
  before do
    CitiesIndex.purge!
    Chewy.strategy(:urgent) do
      City.create!(name: 'London', population: 9_000_000)
      City.create!(name: 'Bangkok', population: 11_000_000)
      City.create!(name: 'Lisbon', population: 500_000)
    end
    CitiesIndex.refresh
  end

  it 'finds cities by name' do
    results = CitiesIndex.query(match: {name: 'London'})
    expect(results.count).to eq(1)
    expect(results.first.name).to eq('London')
  end

  it 'filters by population' do
    results = CitiesIndex.filter(range: {population: {gte: 10_000_000}})
    expect(results.count).to eq(1)
  end
end
```

Use `purge!` to clear the index, `:urgent` strategy so records are indexed
immediately, and `refresh` to ensure documents are searchable before asserting.

If you're seeing other unexpected behavior in tests, check [troubleshooting.md](troubleshooting.md) for common issues and debugging tips.

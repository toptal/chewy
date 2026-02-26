# Getting Started with Chewy

This tutorial walks you through building search for a small media library app
(books and authors) using Chewy 8.x, Elasticsearch 8.x and Rails 7.2+.
By the end you will have an index, automatic model updates, a reusable search
form object, a controller that serves results, and tests.

## Prerequisites

| Dependency | Version |
|---|---|
| Ruby | 3.2+ |
| Rails | 7.2+ |
| Chewy | 8.x |
| Elasticsearch | 8.x |

Start Elasticsearch with Docker:

```shell
docker run --rm -p 9200:9200 -e "discovery.type=single-node" \
  -e "xpack.security.enabled=false" elasticsearch:8.15.0
```

Add Chewy to your Gemfile and bundle:

```ruby
gem 'chewy'
```

## Configuration

Generate the config file:

```shell
rails g chewy:install
```

This creates `config/chewy.yml`. A minimal setup:

```yaml
# config/chewy.yml
development:
  host: 'localhost:9200'
test:
  host: 'localhost:9200'
  prefix: 'test'
```

See [configuration.md](configuration.md) for the full list of options including
async strategies, AWS and Elastic Cloud setups.

## Models

For this tutorial we have two ActiveRecord models:

```ruby
# app/models/author.rb
class Author < ApplicationRecord
  has_many :books
end

# app/models/book.rb
class Book < ApplicationRecord
  belongs_to :author
end
```

With a schema roughly like:

```ruby
create_table :authors do |t|
  t.string :name
  t.timestamps
end

create_table :books do |t|
  t.string :title
  t.text :description
  t.string :genre
  t.integer :year
  t.references :author
  t.timestamps
end
```

## Defining an index

Create `app/chewy/books_index.rb`:

```ruby
class BooksIndex < Chewy::Index
  settings analysis: {
    analyzer: {
      sorted: {
        tokenizer: 'keyword',
        filter: ['lowercase']
      }
    }
  }

  index_scope Book.includes(:author)

  field :title, type: 'text' do
    field :sorted, analyzer: 'sorted'   # keyword sub-field for sorting
  end
  field :description, type: 'text'
  field :genre, type: 'keyword'
  field :year, type: 'integer'
  field :author, type: 'object', value: ->(book) { {name: book.author.name} } do
    field :name, type: 'text' do
      field :raw, type: 'keyword'
    end
  end
end
```

Key points:

- `index_scope` tells Chewy which records to index and lets it eager-load
  associations.
- The `sorted` sub-field on `title` uses a `keyword` tokenizer so you can
  `order('title.sorted')` without case-sensitivity issues.
- The `author` object is denormalized into the book document — this is how
  you search across associations with Elasticsearch.

See [indexing.md](indexing.md) for the full field DSL, crutches and witchcraft.

## Connecting models

Add `update_index` callbacks so Chewy knows when to reindex:

```ruby
class Book < ApplicationRecord
  belongs_to :author

  update_index('books') { self }
end

class Author < ApplicationRecord
  has_many :books

  # When an author's name changes, reindex all their books
  update_index('books') { books }
end
```

The first argument is the index name (without the `Index` suffix).
The block returns the object(s) that need reindexing — for the `Author` callback
that means all of the author's books, since the author name is denormalized
into each book document.

## Importing data

Populate the index for the first time:

```shell
rails chewy:reset[books]
```

Or from Ruby code:

```ruby
BooksIndex.reset!
```

Verify with a quick query in the console:

```ruby
Chewy.strategy(:urgent)
BooksIndex.query(match_all: {}).count
```

## Understanding strategies

If you save a model with an `update_index` callback outside a strategy block,
Chewy raises `Chewy::UndefinedUpdateStrategy`. This is intentional — it forces
you to pick the right strategy for the context.

In a Rails app the middleware sets `:atomic` for controller actions automatically.
For other contexts, wrap your code:

```ruby
Chewy.strategy(:atomic) do
  Book.find_each { |b| b.update!(title: b.title.titleize) }
end
```

| Strategy | When to use |
|---|---|
| `:atomic` | Default for web requests. Batches updates, one bulk call at end of block. |
| `:urgent` | Rails console / one-off scripts. Updates immediately per save. |
| `:sidekiq` | Background reindexing via Sidekiq. |
| `:active_job` | Background reindexing via ActiveJob. |
| `:bypass` | Tests or migrations where you don't want automatic indexing. |

See [configuration.md](configuration.md#index-update-strategies) for the full
list including `:lazy_sidekiq` and `:delayed_sidekiq`.

## Building a search form object

A search form object is a plain Ruby class that composes Chewy scopes into a
single query. This pattern keeps search logic out of your controllers and makes
it easy to test.

```ruby
# app/form_objects/book_search.rb
class BookSearch
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :q, :string
  attribute :genre, :string
  attribute :year_from, :integer
  attribute :year_to, :integer
  attribute :author, :string
  attribute :sort, :string

  # Returns a Chewy::Search::Request
  def search
    [keyword_query, genre_filter, year_filter, author_filter, sorting]
      .compact
      .reduce(BooksIndex.all) { |scope, clause| scope.merge(clause) }
  end

  private

  def keyword_query
    return if q.blank?

    BooksIndex.query(
      multi_match: {
        query: q,
        fields: ['title^2', 'description', 'author.name'],
        type: 'best_fields'
      }
    )
  end

  def genre_filter
    return if genre.blank?

    BooksIndex.filter(term: {genre: genre})
  end

  def year_filter
    range = {}
    range[:gte] = year_from if year_from.present?
    range[:lte] = year_to if year_to.present?
    return if range.empty?

    BooksIndex.filter(range: {year: range})
  end

  def author_filter
    return if author.blank?

    BooksIndex.filter(match: {'author.name': author})
  end

  def sorting
    case sort
    when 'title'
      BooksIndex.order('title.sorted': :asc)
    when 'year_desc'
      BooksIndex.order(year: :desc)
    when 'year_asc'
      BooksIndex.order(year: :asc)
    else
      nil  # relevance (default _score ordering)
    end
  end
end
```

Each private method returns a `Chewy::Search::Request` or `nil`.
The `search` method merges them together — Chewy scopes are chainable and
mergeable just like ActiveRecord scopes.

## Controller and view

```ruby
class BooksController < ApplicationController
  def index
    form = BookSearch.new(search_params)
    @books = form.search
                 .load(scope: -> { includes(:author) })
                 .page(params[:page]).per(20)
  rescue Elasticsearch::Transport::Transport::Errors::BadRequest
    # Malformed user query — fall back to empty results
    @books = Book.none.page(params[:page])
    flash.now[:alert] = 'Invalid search query.'
  end

  private

  def search_params
    params.permit(:q, :genre, :year_from, :year_to, :author, :sort)
  end
end
```

- `.load(scope: -> { includes(:author) })` fetches the actual ActiveRecord
  objects (with eager-loaded authors) so you can use them in views.
- `.page` / `.per` work via Kaminari integration.
- The `rescue` catches malformed queries (e.g. unbalanced parentheses in a
  `query_string` query) so they don't crash the page.

## Sorting

In the index we defined a `sorted` sub-field on `title` with a `keyword`
analyzer. This lets us sort alphabetically without tokenization artifacts:

```ruby
BooksIndex.order('title.sorted': :asc)
```

You can combine multiple sort clauses:

```ruby
BooksIndex.order(year: :desc, 'title.sorted': :asc)
```

The default sort is by `_score` (relevance). To sort explicitly by score:

```ruby
BooksIndex.order(:_score)
```

See [querying.md](querying.md#sorting) for more details.

## Testing

Add to `spec/spec_helper.rb` (or `rails_helper.rb`):

```ruby
require 'chewy/rspec'

RSpec.configure do |config|
  config.before(:suite) do
    Chewy.strategy(:bypass)
  end
end
```

### Testing index updates

The `update_index` matcher verifies that model changes trigger the right
index operations:

```ruby
RSpec.describe Book, type: :model do
  specify do
    book = create(:book)
    expect { book.update!(title: 'New Title') }
      .to update_index(BooksIndex).and_reindex(book)
  end

  specify do
    book = create(:book)
    expect { book.destroy! }
      .to update_index(BooksIndex).and_delete(book)
  end
end
```

### Testing search results

To test that your queries return the right documents, import data into a
real Elasticsearch index and query it:

```ruby
RSpec.describe BookSearch do
  before do
    BooksIndex.purge!
    Chewy.strategy(:urgent) do
      create(:book, title: 'Elasticsearch in Action', genre: 'tech', year: 2015)
      create(:book, title: 'Ruby Under a Microscope', genre: 'tech', year: 2013)
      create(:book, title: 'Moby Dick', genre: 'fiction', year: 1851)
    end
    BooksIndex.refresh
  end

  it 'filters by genre' do
    results = BookSearch.new(genre: 'tech').search
    expect(results.count).to eq(2)
  end

  it 'searches by keyword' do
    results = BookSearch.new(q: 'Elasticsearch').search
    expect(results.count).to eq(1)
  end
end
```

See [testing.md](testing.md) for the full RSpec/Minitest API including
`mock_elasticsearch_response` and Minitest helpers.

## Next steps

- [Configuration](configuration.md) — strategies, async workers, notifications
- [Indexing](indexing.md) — full field DSL, crutches, witchcraft, geo points
- [Import](import.md) — batching, raw import, journaling
- [Querying](querying.md) — DSL details, pagination, scroll API, loading
- [Rake Tasks](rake_tasks.md) — resetting, syncing, parallel execution
- [Testing](testing.md) — matchers, mocking, DatabaseCleaner
- [Troubleshooting](troubleshooting.md) — common errors and debugging

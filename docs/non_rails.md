# Using Chewy Without Rails

Chewy works perfectly fine outside of Rails. The only hard dependencies are `activesupport` and `elasticsearch`; the Rails railtie loads conditionally ([lib/chewy.rb:51](../lib/chewy.rb#L51)).

## Setup

Without Rails there is no `chewy.yml` auto-loading or generator. Configure the client directly:

```ruby
require 'chewy'

Chewy.settings = {
  host: 'localhost:9200',
  prefix: 'my_app'
}

Chewy.logger = Logger.new($stdout)
```

## Defining an index

Without ActiveRecord, use the Object adapter. You can omit `index_scope` entirely or point it at a plain Ruby class:

```ruby
class ArticlesIndex < Chewy::Index
  field :id, type: :integer
  field :title
  field :body

  # Optional: if you provide a class with a .call method,
  # Chewy uses it as the default data source on reset/import.
  # index_scope -> { MyDataSource.all }, name: 'article'
end
```

Import data by passing arrays of hashes or objects that respond to the field methods:

```ruby
Chewy.strategy(:atomic) do
  ArticlesIndex.import([
    {id: 1, title: 'First', body: 'Hello'},
    {id: 2, title: 'Second', body: 'World'}
  ])
end
```

## Strategy management

In Rails, the railtie wraps controller actions with a strategy (`:atomic` by default) and sets up the console and migration strategies automatically. Without Rails you must manage this yourself.

Either wrap your code in a strategy block:

```ruby
Chewy.strategy(:atomic) do
  # your import / update code
end
```

Or set a root strategy to avoid `UndefinedUpdateStrategy` errors:

```ruby
Chewy.root_strategy = :bypass
```

See [configuration.md](configuration.md#index-update-strategies) for the full list of strategies.

## Querying

The query DSL works identically regardless of framework:

```ruby
ArticlesIndex.query(match: {title: 'hello'}).to_a
ArticlesIndex.filter(term: {id: 1}).first
```

See [querying.md](querying.md) for the full DSL reference.

## Rake tasks

The railtie auto-loads Chewy's rake tasks. Without it you have two options:

1. Load the tasks in your `Rakefile`:

   ```ruby
   require 'chewy'
   load 'tasks/chewy.rake'
   ```

2. Call `Chewy::RakeHelper` methods directly from your own scripts:

   ```ruby
   Chewy::RakeHelper.reset(only: 'articles')
   ```

## Minimal working example

A self-contained script you can run with `ruby example.rb` (assumes Elasticsearch is running on localhost:9200):

```ruby
require 'chewy'

Chewy.settings = {host: 'localhost:9200'}
Chewy.logger = Logger.new($stdout)

class BooksIndex < Chewy::Index
  field :id, type: :integer
  field :title
  field :author
end

# Create the index and import data
Chewy.strategy(:atomic) do
  BooksIndex.reset!
  BooksIndex.import([
    {id: 1, title: 'The Ruby Way', author: 'Hal Fulton'},
    {id: 2, title: 'Eloquent Ruby', author: 'Russ Olsen'}
  ])
end

# Wait for ES to refresh
sleep 1

# Query
results = BooksIndex.query(match: {title: 'ruby'})
results.each { |doc| puts "#{doc.title} by #{doc.author}" }
```

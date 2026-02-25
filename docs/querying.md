# Querying

## Composing requests

The request DSL have the same chainable nature as AR. The main class is `Chewy::Search::Request`.

```ruby
CitiesIndex.query(match: {name: 'London'})
```

Main methods of the request DSL are: `query`, `filter` and `post_filter`, it is possible to pass pure query hashes or use `elasticsearch-dsl`.

```ruby
CitiesIndex
  .filter(term: {name: 'Bangkok'})
  .query(match: {name: 'London'})
  .query.not(range: {population: {gt: 1_000_000}})
```

You can query a set of indexes at once:

```ruby
CitiesIndex.indices(CountriesIndex).query(match: {name: 'Some'})
```

See https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html and https://github.com/elastic/elasticsearch-dsl-ruby for more details.

An important part of requests manipulation is merging. There are 4 methods to perform it: `merge`, `and`, `or`, `not`. See [Chewy::Search::QueryProxy](../lib/chewy/search/query_proxy.rb) for details. Also, `only` and `except` methods help to remove unneeded parts of the request.

Every other request part is covered by a bunch of additional methods, see [Chewy::Search::Request](../lib/chewy/search/request.rb) for details:

```ruby
CitiesIndex.limit(10).offset(30).order(:name, {population: {order: :desc}})
```

Request DSL also provides additional scope actions, like `delete_all`, `exists?`, `count`, `pluck`, etc.

## Pagination

The request DSL supports pagination with `Kaminari`. An extension is enabled on initialization if `Kaminari` is available. See [Chewy::Search](../lib/chewy/search.rb) and [Chewy::Search::Pagination::Kaminari](../lib/chewy/search/pagination/kaminari.rb) for details.

## Named scopes

Chewy supports named scopes functionality. There is no specialized DSL for named scopes definition, it is simply about defining class methods.

See [Chewy::Search::Scoping](../lib/chewy/search/scoping.rb) for details.

## Scroll API

Elasticsearch scroll API is utilized by a bunch of methods: `scroll_batches`, `scroll_hits`, `scroll_wrappers` and `scroll_objects`.

See [Chewy::Search::Scrolling](../lib/chewy/search/scrolling.rb) for details.

## Loading objects

It is possible to load ORM/ODM source objects with the `objects` method. To provide additional loading options use `load` method:

```ruby
CitiesIndex.load(scope: -> { active }).to_a # to_a returns `Chewy::Index` wrappers.
CitiesIndex.load(scope: -> { active }).objects # An array of AR source objects.
```

See [Chewy::Search::Loader](../lib/chewy/search/loader.rb) for more details.

In case when it is necessary to iterate through both of the wrappers and objects simultaneously, `object_hash` method helps a lot:

```ruby
scope = CitiesIndex.load(scope: -> { active })
scope.each do |wrapper|
  scope.object_hash[wrapper]
end
```

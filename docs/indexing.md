# Indexing

## Index definition

1. Create `/app/chewy/users_index.rb`

  ```ruby
  class UsersIndex < Chewy::Index

  end
  ```

2. Define index scope (you can omit this part if you don't need to specify a scope (i.e. use PORO objects for import) or options)

  ```ruby
  class UsersIndex < Chewy::Index
    index_scope User.active # or just model instead_of scope: index_scope User
  end
  ```

3. Add some mappings

  ```ruby
  class UsersIndex < Chewy::Index
    index_scope User.active.includes(:country, :badges, :projects)
    field :first_name, :last_name # multiple fields without additional options
    field :email, analyzer: 'email' # Elasticsearch-related options
    field :country, value: ->(user) { user.country.name } # custom value proc
    field :badges, value: ->(user) { user.badges.map(&:name) } # passing array values to index
    field :projects do # the same block syntax for multi_field, if `:type` is specified
      field :title
      field :description # default data type is `text`
      # additional top-level objects passed to value proc:
      field :categories, value: ->(project, user) { project.categories.map(&:name) if user.active? }
    end
    field :rating, type: 'integer' # custom data type
    field :created, type: 'date', include_in_all: false,
      value: ->{ created_at } # value proc for source object context
  end
  ```

  [See here for mapping definitions](https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping.html).

4. Add some index-related settings. Analyzer repositories might be used as well. See `Chewy::Index.settings` docs for details:

  ```ruby
  class UsersIndex < Chewy::Index
    settings analysis: {
      analyzer: {
        email: {
          tokenizer: 'keyword',
          filter: ['lowercase']
        }
      }
    }

    index_scope User.active.includes(:country, :badges, :projects)
    root date_detection: false do
      template 'about_translations.*', type: 'text', analyzer: 'standard'

      field :first_name, :last_name
      field :email, analyzer: 'email'
      field :country, value: ->(user) { user.country.name }
      field :badges, value: ->(user) { user.badges.map(&:name) }
      field :projects do
        field :title
        field :description
      end
      field :about_translations, type: 'object' # pass object type explicitly if necessary
      field :rating, type: 'integer'
      field :created, type: 'date', include_in_all: false,
        value: ->{ created_at }
    end
  end
  ```

  [See index settings here](https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-update-settings.html).
  [See root object settings here](https://www.elastic.co/guide/en/elasticsearch/reference/current/dynamic-field-mapping.html).

  See [mapping.rb](../lib/chewy/index/mapping.rb) for more details.

5. Add model-observing code

  ```ruby
  class User < ActiveRecord::Base
    update_index('users') { self } # specifying index and back-reference
                                        # for updating after user save or destroy
  end

  class Country < ActiveRecord::Base
    has_many :users

    update_index('users') { users } # return single object or collection
  end

  class Project < ActiveRecord::Base
    update_index('users') { user if user.active? } # you can return even `nil` from the back-reference
  end

  class Book < ActiveRecord::Base
    update_index(->(book) {"books_#{book.language}"}) { self } # dynamic index name with proc.
                                                               # For book with language == "en"
                                                               # this code will generate `books_en`
  end
  ```

  The `update_index` callback requires an active update strategy to be set. See [configuration.md](configuration.md#index-update-strategies) for available strategies and how they integrate with Rails.

  Also, you can use the second argument for method name passing:

  ```ruby
  update_index('users', :self)
  update_index('users', :users)
  ```

  In the case of a belongs_to association you may need to update both associated objects, previous and current:

  ```ruby
  class City < ActiveRecord::Base
    belongs_to :country

    update_index('cities') { self }
    update_index 'countries' do
      previous_changes['country_id'] || country
    end
  end
  ```

## Multi (nested) and object field types

To define an objects field you can simply nest fields in the DSL:

```ruby
field :projects do
  field :title
  field :description
end
```

This will automatically set the type or root field to `object`. You may also specify `type: 'objects'` explicitly.

To define a multi field you have to specify any type except for `object` or `nested` in the root field:

```ruby
field :full_name, type: 'text', value: ->{ full_name.strip } do
  field :ordered, analyzer: 'ordered'
  field :untouched, type: 'keyword'
end
```

The `value:` option for internal fields will no longer be effective.

A common use for multi-fields is adding a keyword sub-field for sorting.
Text fields are tokenized and cannot be sorted directly, but a keyword
sub-field preserves the original value:

```ruby
field :title, type: 'text' do
  field :sorted, type: 'keyword'
end
```

Then sort with `BooksIndex.order('title.sorted': :asc)`. You can also use a
custom analyzer (e.g. `keyword` tokenizer + `lowercase` filter) if you want
case-insensitive sorting.

## Geo Point fields

You can use [Elasticsearch's geo mapping](https://www.elastic.co/guide/en/elasticsearch/reference/current/geo-point.html) with the `geo_point` field type, allowing you to query, filter and order by latitude and longitude. You can use the following hash format:

```ruby
field :coordinates, type: 'geo_point', value: ->{ {lat: latitude, lon: longitude} }
```

or by using nested fields:

```ruby
field :coordinates, type: 'geo_point' do
  field :lat, value: ->{ latitude }
  field :long, value: ->{ longitude }
end
```

See the section on *Script fields* for details on calculating distance in a search.

## Join fields

You can use a [join field](https://www.elastic.co/guide/en/elasticsearch/reference/current/parent-join.html)
to implement parent-child relationships between documents.
It [replaces the old `parent_id` based parent-child mapping](https://www.elastic.co/guide/en/elasticsearch/reference/current/removal-of-types.html#parent-child-mapping-types)

To use it, you need to pass `relations` and `join` (with `type` and `id`) options:
```ruby
field :hierarchy_link, type: :join, relations: {question: %i[answer comment], answer: :vote, vote: :subvote}, join: {type: :comment_type, id: :commented_id}
```
assuming you have `comment_type` and `commented_id` fields in your model.

Note that when you reindex a parent, its children and grandchildren will be reindexed as well.
This may require additional queries to the primary database and to Elasticsearch.

Also note that the join field doesn't support crutches (it should be a field directly defined on the model).

## Crutches technology

Assume you are defining your index like this (product has_many categories through product_categories):

```ruby
class ProductsIndex < Chewy::Index
  index_scope Product.includes(:categories)
  field :name
  field :category_names, value: ->(product) { product.categories.map(&:name) } # or shorter just -> { categories.map(&:name) }
end
```

Then the Chewy reindexing flow will look like the following pseudo-code:

```ruby
Product.includes(:categories).find_in_batches(1000) do |batch|
  bulk_body = batch.map do |object|
    {name: object.name, category_names: object.categories.map(&:name)}.to_json
  end
  # here we are sending every batch of data to ES
  Chewy.client.bulk bulk_body
end
```

If you meet complicated cases when associations are not applicable you can replace Rails associations with Chewy Crutches technology:

```ruby
class ProductsIndex < Chewy::Index
  index_scope Product
  crutch :categories do |collection| # collection here is a current batch of products
    # data is fetched with a lightweight query without objects initialization
    data = ProductCategory.joins(:category).where(product_id: collection.map(&:id)).pluck(:product_id, 'categories.name')
    # then we have to convert fetched data to appropriate format
    # this will return our data in structure like:
    # {123 => ['sweets', 'juices'], 456 => ['meat']}
    data.each.with_object({}) { |(id, name), result| (result[id] ||= []).push(name) }
  end

  field :name
  # simply use crutch-fetched data as a value:
  field :category_names, value: ->(product, crutches) { crutches[:categories][product.id] }
end
```

An example flow will look like this:

```ruby
Product.includes(:categories).find_in_batches(1000) do |batch|
  crutches[:categories] = ProductCategory.joins(:category).where(product_id: batch.map(&:id)).pluck(:product_id, 'categories.name')
    .each.with_object({}) { |(id, name), result| (result[id] ||= []).push(name) }

  bulk_body = batch.map do |object|
    {name: object.name, category_names: crutches[:categories][object.id]}.to_json
  end
  Chewy.client.bulk bulk_body
end
```

So Chewy Crutches technology is able to increase your indexing performance in some cases up to a hundredfold or even more depending on your associations complexity. For another approach to import performance, see [Raw import](import.md#raw-import).

## Compiled compose path

Every index automatically uses a compiled compose path: on the first import, Chewy generates one `__chewy_compose__` method per index from the field tree and calls it for every object instead of iterating through the field list at runtime.
This typically gives **3-4× faster document composition** over the legacy iterative path with no code change required and no extra dependencies.

The compiler:

- Inlines the hash literal for the index document.
- Bakes each field's accessor (method call, hash key lookup, or proc dispatch) directly into the generated source.
- Calls value procs with exactly the arguments they declare (`(object)`, `(object, crutches)`, or `(object, crutches, context)`), so lambdas with optional arguments don't raise.
- Supports `fields:` restriction by generating a separate cached method per unique fields set, so `update_fields:` partial imports stay on the fast path.

There is nothing to opt into.
The compiled path also handles hash inputs, join fields, and nested object fields the same way the legacy path did.

For a small number of edge cases the compiler falls back to the legacy path automatically: `ignore_blank` fields, `geo_point` fields, indexes with a custom root value proc, and fields whose name is not a valid Ruby identifier.
The fallback is transparent — the compose result is identical either way.

## Witchcraft technology (deprecated)

> **Deprecated**.
> `witchcraft!` is retained only for compatibility with older index definitions and will be removed in a future major release.
> The compiled compose path above is the default for all indexes and delivers equivalent performance without `method_source` / `parser` / `prism` / `unparser` dependencies, with substantially lower boot-time memory (see [#644](https://github.com/toptal/chewy/issues/644)).
> Remove the `witchcraft!` call from your index — no other changes are needed.

Witchcraft was an experimental performance optimization that used `method_source` to read each field value proc's Ruby source, parse it with `parser` or `prism`, rewrite the AST, and `Unparser`-emit a single fused lambda per index.
Concretely it compiled definitions like this:

```ruby
index_scope Product
witchcraft!

field :title
field :tags, value: -> { tags.map(&:name) }
field :categories do
  field :name, value: -> (product, category) { category.name }
  field :type, value: -> (product, category, crutch) { crutch.types[category.name] }
end
```

into a single lambda roughly equivalent to:

```ruby
-> (object, crutches) do
  {
    title: object.title,
    tags: object.tags.map(&:name),
    categories: object.categories.map do |object2|
      {
        name: object2.name,
        type: crutches.types[object2.name]
      }
    end
  }
end
```

It came with several limitations the compiled path does not have:

1. Required `method_source`-parseable proc source — reflowing a value proc could break the build.
2. Did not support value procs with splat arguments.
3. Required dynamically-generated fields to use procs with explicit arguments rather than argumentless `-> { ... }`.
4. Required `method_source`, `parser` (or `prism`), and `unparser` at boot — together adding ~7 MiB of allocations and ~1 MiB of retained memory to every Rails boot, even for apps that did not call `witchcraft!`.

Calling `witchcraft!` now prints a deprecation warning.
Removing the call switches the index to the compiled path automatically; no other code changes are needed.

## Import context

When importing, you often already have data in memory at the call site (precomputed embeddings, batched API responses, aggregations) that crutches would otherwise re-fetch from the database.
Pass it through via the `context:` keyword on `import` / `import!`.
Context is an arbitrary hash, defaulting to `{}`, that flows into crutch blocks and field value procs.

```ruby
MyIndex.import!(objects, context: { embeddings: precomputed_embeddings })
```

### Context in crutch blocks (2nd argument)

```ruby
crutch :embeddings do |collection, context|
  context[:embeddings] || load_embeddings(collection)
end
```

### Context in field value procs (3rd argument)

```ruby
field :embedding, value: ->(object, crutches, context) {
  context[:override] || crutches.embeddings[object.id]
}
```

Both are backward-compatible: existing 1-arg crutch blocks and 1-2 arg field procs continue to work unchanged via arity-based dispatch.

Context flows through the default compiled compose path automatically, and is also honored under the legacy `witchcraft!` path and under parallel imports (`parallel: N`).
With `parallel:`, the same context hash is shared across all workers — precompute once on the main process, reuse in every worker.

```ruby
MediaIndex.import!(slices, parallel: 4, context: { embeddings: precomputed })
```

## Index manipulation

```ruby
UsersIndex.delete # destroy index if it exists
UsersIndex.delete!

UsersIndex.create
UsersIndex.create! # use bang or non-bang methods

UsersIndex.purge
UsersIndex.purge! # deletes then creates index

UsersIndex.import # import with 0 arguments process all the data specified in index_scope definition
UsersIndex.import User.where('rating > 100') # or import specified users scope
UsersIndex.import User.where('rating > 100').to_a # or import specified users array
UsersIndex.import [1, 2, 42] # pass even ids for import, it will be handled in the most effective way
UsersIndex.import User.where('rating > 100'), update_fields: [:email] # if update fields are specified - it will update their values only with the `update` bulk action
UsersIndex.import! # raises an exception in case of any import errors

UsersIndex.reset! # purges index and imports default data for all types
```

For more on import options, batching and journaling, see [import.md](import.md).

If the passed user is `#destroyed?`, or satisfies a `delete_if` index_scope option, or the specified id does not exist in the database, import will perform delete from index action for this object.

```ruby
index_scope User, delete_if: :deleted_at
index_scope User, delete_if: -> { deleted_at }
index_scope User, delete_if: ->(user) { user.deleted_at }
```

See [actions.rb](../lib/chewy/index/actions.rb) for more details.

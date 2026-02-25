# Import

## Default import options

Every index has `default_import_options` configuration to specify, suddenly, default import options:

```ruby
class ProductsIndex < Chewy::Index
  index_scope Post.includes(:tags)
  default_import_options batch_size: 100, bulk_size: 10.megabytes, refresh: false

  field :name
  field :tags, value: -> { tags.map(&:name) }
end
```

See [import.rb](../lib/chewy/index/import.rb) for available options.

## Raw import

Another way to speed up import time is Raw Imports. This technology is only available in ActiveRecord adapter. Very often, ActiveRecord model instantiation is what consumes most of the CPU and RAM resources. Precious time is wasted on converting, say, timestamps from strings and then serializing them back to strings. Chewy can operate on raw hashes of data directly obtained from the database. All you need is to provide a way to convert that hash to a lightweight object that mimics the behaviour of the normal ActiveRecord object.

```ruby
class LightweightProduct
  def initialize(attributes)
    @attributes = attributes
  end

  # Depending on the database, `created_at` might
  # be in different formats. In PostgreSQL, for example,
  # you might see the following format:
  #   "2016-03-22 16:23:22"
  #
  # Taking into account that Elastic expects something different,
  # one might do something like the following, just to avoid
  # unnecessary String -> DateTime -> String conversion.
  #
  #   "2016-03-22 16:23:22" -> "2016-03-22T16:23:22Z"
  def created_at
    @attributes['created_at'].tr(' ', 'T') << 'Z'
  end
end

index_scope Product
default_import_options raw_import: ->(hash) {
  LightweightProduct.new(hash)
}

field :created_at, 'datetime'
```

Also, you can pass `:raw_import` option to the `import` method explicitly.

## Index creation during import

By default, when you perform import Chewy checks whether an index exists and creates it if it's absent.
You can turn off this feature to decrease Elasticsearch hits count.
To do so you need to set `skip_index_creation_on_import` parameter to `false` in your `config/chewy.yml`.

## Skip record fields during import

You can use `ignore_blank: true` to skip fields that return `true` for the `.blank?` method:

```ruby
index_scope Country
field :id
field :cities, ignore_blank: true do
  field :id
  field :name
  field :surname, ignore_blank: true
  field :description
end
```

### Default values for different types

By default `ignore_blank` is false on every type except `geo_point`.

## Journaling

You can record all actions that were made to the separate journal index in Elasticsearch.
When you create/update/destroy your documents, it will be saved in this special index.
If you make something with a batch of documents (e.g. during index reset) it will be saved as a one record, including primary keys of each document that was affected.
Common journal record looks like this:

```json
{
  "action": "index",
  "object_id": [1, 2, 3],
  "index_name": "...",
  "created_at": "<timestamp>"
}
```

This feature is turned off by default.
You can turn it on by setting `journal` option to `true` in `config/chewy.yml`.

Also, you can provide this option while you're importing some index:

```ruby
CityIndex.import journal: true
```

Or as a default import option for an index:

```ruby
class CityIndex
  index_scope City
  default_import_options journal: true
end
```

You may be wondering why do you need it? The answer is simple: not to lose the data.

Imagine that you reset your index in a zero-downtime manner (to separate index),
and in the meantime somebody keeps updating the data frequently (to old
index). So all these actions will be written to the journal index and you'll be
able to apply them after index reset using the `Chewy::Journal` interface.

When enabled, journal can grow to enormous size, consider setting up cron job
that would clean it occasionally using [`chewy:journal:clean` rake
task](rake_tasks.md#chewyjournal).

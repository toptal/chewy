[![Gem Version](https://badge.fury.io/rb/chewy.svg)](http://badge.fury.io/rb/chewy)
[![GitHub Actions](https://github.com/toptal/chewy/actions/workflows/ruby.yml/badge.svg)](https://github.com/toptal/chewy/actions/workflows/ruby.yml)
[![Code Climate](https://codeclimate.com/github/toptal/chewy.svg)](https://codeclimate.com/github/toptal/chewy)
[![Inline docs](http://inch-ci.org/github/toptal/chewy.svg?branch=master)](http://inch-ci.org/github/toptal/chewy)

# Chewy

Chewy is an ODM (Object Document Mapper), built on top of [the official Elasticsearch client](https://github.com/elastic/elasticsearch-ruby).

## Why Chewy?

In this section we'll cover why you might want to use Chewy instead of the official `elasticsearch-ruby` client gem.

* Every index is observable by all the related models.

  Most of the indexed models are related to other and sometimes it is necessary to denormalize this related data and put at the same object. For example, you need to index an array of tags together with an article. Chewy allows you to specify an updateable index for every model separately - so corresponding articles will be reindexed on any tag update.

* Bulk import everywhere.

  Chewy utilizes the bulk ES API for full reindexing or index updates. It also uses atomic updates. All the changed objects are collected inside the atomic block and the index is updated once at the end with all the collected objects. See `Chewy.strategy(:atomic)` for more details.

* Powerful querying DSL.

  Chewy has an ActiveRecord-style query DSL. It is chainable, mergeable and lazy, so you can produce queries in the most efficient way. It also has object-oriented query and filter builders.

* Support for ActiveRecord.

## Installation

Add this line to your application's `Gemfile`:

    gem 'chewy'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install chewy

## Compatibility

### Ruby

Chewy is compatible with MRI 3.0-3.2¹.

> ¹ Ruby 3 is only supported with Rails 6.1

### Elasticsearch compatibility matrix

| Chewy version | Elasticsearch version              |
| ------------- | ---------------------------------- |
| 7.2.x         | 7.x                                |
| 7.1.x         | 7.x                                |
| 7.0.x         | 6.8, 7.x                           |
| 6.0.0         | 5.x, 6.x                           |
| 5.x           | 5.x, limited support for 1.x & 2.x |

**Important:** Chewy doesn't follow SemVer, so you should always
check the release notes before upgrading. The major version is linked to the
newest supported Elasticsearch and the minor version bumps may include breaking changes.

See our [migration guide](migration_guide.md) for detailed upgrade instructions between
various Chewy versions.

### Active Record

5.2, 6.0, 6.1 Active Record versions are supported by all Chewy versions.

## Getting Started

Chewy provides functionality for Elasticsearch index handling, documents import mappings, index update strategies and chainable query DSL.

### Minimal client setting

Create `config/initializers/chewy.rb` with this line:

```ruby
Chewy.settings = {host: 'localhost:9250'}
```

And run `rails g chewy:install` to generate `chewy.yml`:

```yaml
# config/chewy.yml
# separate environment configs
test:
  host: 'localhost:9250'
  prefix: 'test'
development:
  host: 'localhost:9200'
```

### Elasticsearch

Make sure you have Elasticsearch up and running. You can [install](https://www.elastic.co/guide/en/elasticsearch/reference/current/install-elasticsearch.html) it locally, but the easiest way is to use [Docker](https://www.docker.com/get-started):

```shell
$ docker run --rm --name elasticsearch -p 9200:9200 -p 9300:9300 -e "discovery.type=single-node" elasticsearch:7.11.1
```

### Index

Create `app/chewy/users_index.rb` with User Index:

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

  index_scope User
  field :first_name
  field :last_name
  field :email, analyzer: 'email'
end
```

### Model

Add User model, table and migrate it:

```shell
$ bundle exec rails g model User first_name last_name email
$ bundle exec rails db:migrate
```

Add `update_index` to app/models/user.rb:

```ruby
class User < ApplicationRecord
  update_index('users') { self }
end
```

### Example of data request

1. Once a record is created (could be done via the Rails console), it creates User index too:

```
User.create(
  first_name: "test1",
  last_name: "test1",
  email: 'test1@example.com',
  # other fields
)
# UsersIndex Import (355.3ms) {:index=>1}
# => #<User id: 1, first_name: "test1", last_name: "test1", email: "test1@example.com", # other fields>
```

2. A query could be exposed at a given `UsersController`:

```ruby
def search
  @users = UsersIndex.query(query_string: { fields: [:first_name, :last_name, :email, ...], query: search_params[:query], default_operator: 'and' })
  render json: @users.to_json, status: :ok
end

private

def search_params
  params.permit(:query, :page, :per)
end
```

3. So a request against `http://localhost:3000/users/search?query=test1@example.com` issuing a response like:

```json
[
  {
    "attributes":{
      "id":"1",
      "first_name":"test1",
      "last_name":"test1",
      "email":"test1@example.com",
      ...
      "_score":0.9808291,
      "_explanation":null
    },
    "_data":{
      "_index":"users",
      "_type":"_doc",
      "_id":"1",
      "_score":0.9808291,
      "_source":{
        "first_name":"test1",
        "last_name":"test1",
        "email":"test1@example.com",
        ...
      }
    }
  }
]
```

## Usage and configuration

### Client settings

To configure the Chewy client you need to add `chewy.rb` file with `Chewy.settings` hash:

```ruby
# config/initializers/chewy.rb
Chewy.settings = {host: 'localhost:9250'} # do not use environments
```

And add `chewy.yml` configuration file.

You can create `chewy.yml` manually or run `rails g chewy:install` to generate it:

```yaml
# config/chewy.yml
# separate environment configs
test:
  host: 'localhost:9250'
  prefix: 'test'
development:
  host: 'localhost:9200'
```

The resulting config merges both hashes. Client options are passed as is to `Elasticsearch::Transport::Client` except for the `:prefix`, which is used internally by Chewy to create prefixed index names:

```ruby
  Chewy.settings = {prefix: 'test'}
  UsersIndex.index_name # => 'test_users'
```

The logger may be set explicitly:

```ruby
Chewy.logger = Logger.new(STDOUT)
```

See [config.rb](lib/chewy/config.rb) for more details.

#### AWS Elasticsearch

If you would like to use AWS's Elasticsearch using an IAM user policy, you will need to sign your requests for the `es:*` action by injecting the appropriate headers passing a proc to `transport_options`.
You'll need an additional gem for Faraday middleware: add `gem 'faraday_middleware-aws-sigv4'` to your Gemfile.

```ruby
require 'faraday_middleware/aws_sigv4'

Chewy.settings = {
  host: 'http://my-es-instance-on-aws.us-east-1.es.amazonaws.com:80',
  port: 80, # 443 for https host
  transport_options: {
    headers: { content_type: 'application/json' },
    proc: -> (f) do
        f.request :aws_sigv4,
                  service: 'es',
                  region: 'us-east-1',
                  access_key_id: ENV['AWS_ACCESS_KEY'],
                  secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    end
  }
}
```

#### Index definition

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

  See [mapping.rb](lib/chewy/index/mapping.rb) for more details.

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

### Default import options

Every index has `default_import_options` configuration to specify, suddenly, default import options:

```ruby
class ProductsIndex < Chewy::Index
  index_scope Post.includes(:tags)
  default_import_options batch_size: 100, bulk_size: 10.megabytes, refresh: false

  field :name
  field :tags, value: -> { tags.map(&:name) }
end
```

See [import.rb](lib/chewy/index/import.rb) for available options.

### Multi (nested) and object field types

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

### Geo Point fields

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

### Join fields

You can use a [join field](https://www.elastic.co/guide/en/elasticsearch/reference/current/parent-join.html)
to implement parent-child relationships between documents.
It [replaces the old `parent_id` based parent-child mapping](https://www.elastic.co/guide/en/elasticsearch/reference/current/removal-of-types.html#parent-child-mapping-types)

To use it, you need to pass `relations` and `join` (with `type` and `id`) options:
```ruby
field :hierarchy_link, type: :join, relations: {question: %i[answer comment], answer: :vote, vote: :subvote}, join: {type: :comment_type, id: :commented_id}
```
assuming you have `comment_type` and `commented_id` fields in your model.

Note that when you reindex a parent, its children and grandchildren will be reindexed as well.
This may require additional queries to the primary database and to elastisearch.

Also note that the join field doesn't support crutches (it should be a field directly defined on the model).

### Crutches™ technology

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

If you meet complicated cases when associations are not applicable you can replace Rails associations with Chewy Crutches™ technology:

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

So Chewy Crutches™ technology is able to increase your indexing performance in some cases up to a hundredfold or even more depending on your associations complexity.

### Witchcraft™ technology

One more experimental technology to increase import performance. As far as you know, chewy defines value proc for every imported field in mapping, so at the import time each of these procs is executed on imported object to extract result document to import. It would be great for performance to use one huge whole-document-returning proc instead. So basically the idea or Witchcraft™ technology is to compile a single document-returning proc from the index definition.

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

The index definition above will be compiled to something close to:

```ruby
-> (object, crutches) do
  {
    title: object.title,
    tags: object.tags.map(&:name),
    categories: object.categories.map do |object2|
      {
        name: object2.name
        type: crutches.types[object2.name]
      }
    end
  }
end
```

And don't even ask how is it possible, it is a witchcraft.
Obviously not every type of definition might be compiled. There are some restrictions:

1. Use reasonable formatting to make `method_source` be able to extract field value proc sources.
2. Value procs with splat arguments are not supported right now.
3. If you are generating fields dynamically use value proc with arguments, argumentless value procs are not supported yet:

  ```ruby
  [:first_name, :last_name].each do |name|
    field name, value: -> (o) { o.send(name) }
  end
  ```

However, it is quite possible that your index definition will be supported by Witchcraft™ technology out of the box in most of the cases.

### Raw Import

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

### Index creation during import

By default, when you perform import Chewy checks whether an index exists and creates it if it's absent.
You can turn off this feature to decrease Elasticsearch hits count.
To do so you need to set `skip_index_creation_on_import` parameter to `false` in your `config/chewy.yml`

### Skip record fields during import

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

#### Default values for different types

By default `ignore_blank` is false on every type except `geo_point`.

### Journaling

You can record all actions that were made to the separate journal index in ElasticSearch.
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
But you can turn it on by setting `journal` setting to `true` in `config/chewy.yml`.
Also, you can specify journal index name. For example:

```yaml
# config/chewy.yml
production:
  journal: true
  journal_name: my_super_journal
```

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

Imagine that you reset your index in a zero-downtime manner (to separate index), and in the meantime somebody keeps updating the data frequently (to old index). So all these actions will be written to the journal index and you'll be able to apply them after index reset using the `Chewy::Journal` interface.

When enabled, journal can grow to enormous size, consider setting up cron job that would clean it occasionally using [`chewy:journal:clean` rake task](#chewyjournal).

### Index manipulation

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

If the passed user is `#destroyed?`, or satisfies a `delete_if` index_scope option, or the specified id does not exist in the database, import will perform delete from index action for this object.

```ruby
index_scope User, delete_if: :deleted_at
index_scope User, delete_if: -> { deleted_at }
index_scope User, delete_if: ->(user) { user.deleted_at }
```

See [actions.rb](lib/chewy/index/actions.rb) for more details.

### Index update strategies

Assume you've got the following code:

```ruby
class City < ActiveRecord::Base
  update_index 'cities', :self
end

class CitiesIndex < Chewy::Index
  index_scope City
  field :name
end
```

If you do something like `City.first.save!` you'll get an UndefinedUpdateStrategy exception instead of the object saving and index updating. This exception forces you to choose an appropriate update strategy for the current context.

If you want to return to the pre-0.7.0 behavior - just set `Chewy.root_strategy = :bypass`.

#### `:atomic`

The main strategy here is `:atomic`. Assume you have to update a lot of records in the db.

```ruby
Chewy.strategy(:atomic) do
  City.popular.map(&:do_some_update_action!)
end
```

Using this strategy delays the index update request until the end of the block. Updated records are aggregated and the index update happens with the bulk API. So this strategy is highly optimized.

#### `:sidekiq`

This does the same thing as `:atomic`, but asynchronously using sidekiq. Patch `Chewy::Strategy::Sidekiq::Worker` for index updates improving.

```ruby
Chewy.strategy(:sidekiq) do
  City.popular.map(&:do_some_update_action!)
end
```

The default queue name is `chewy`, you can customize it in settings: `sidekiq.queue_name`
```
Chewy.settings[:sidekiq] = {queue: :low}
```

#### `:lazy_sidekiq`

This does the same thing as `:sidekiq`, but with lazy evaluation. Beware it does not allow you to use any non-persistent record state for indices and conditions because record will be re-fetched from database asynchronously using sidekiq. However for destroying records strategy will fallback to `:sidekiq` because it's not possible to re-fetch deleted records from database.

The purpose of this strategy is to improve the response time of the code that should update indexes, as it does not only defer actual ES calls to a background job but `update_index` callbacks evaluation (for created and updated objects) too. Similar to `:sidekiq`, index update is asynchronous so this strategy cannot be used when data and index synchronization is required.

```ruby
Chewy.strategy(:lazy_sidekiq) do
  City.popular.map(&:do_some_update_action!)
end
```

The default queue name is `chewy`, you can customize it in settings: `sidekiq.queue_name`
```
Chewy.settings[:sidekiq] = {queue: :low}
```

#### `:delayed_sidekiq`

It accumulates ids of records to be reindexed during the latency window in redis and then does the reindexing of all accumulated records at once.
The strategy is very useful in case of frequently mutated records.
It supports `update_fields` option, so it will try to select just enough data from the DB

There are three options that can be defined in the index:
```ruby
class CitiesIndex...
  strategy_config delayed_sidekiq: {
    latency: 3,
    margin: 2,
    ttl: 60 * 60 * 24,
    reindex_wrapper: ->(&reindex) {
      ActiveRecord::Base.connected_to(role: :reading) { reindex.call }
    }
    # latency - will prevent scheduling identical jobs
    # margin - main purpose is to cover db replication lag by the margin
    # ttl - a chunk expiration time (in seconds)
    # reindex_wrapper - lambda that accepts block to wrap that reindex process AR connection block.
  }

  ...
end
```

Also you can define defaults in the `initializers/chewy.rb`
```ruby
Chewy.settings = {
  strategy_config: {
    delayed_sidekiq: {
      latency: 3,
      margin: 2,
      ttl: 60 * 60 * 24,
      reindex_wrapper: ->(&reindex) {
        ActiveRecord::Base.connected_to(role: :reading) { reindex.call }
      }
    }
  }
}

```
or in `config/chewy.yml`
```ruby
  strategy_config:
    delayed_sidekiq:
      latency: 3
      margin: 2
      ttl: <%= 60 * 60 * 24 %>
      # reindex_wrapper setting is not possible here!!! use the initializer instead
```

You can use the strategy identically to other strategies
```ruby
Chewy.strategy(:delayed_sidekiq) do
  City.popular.map(&:do_some_update_action!)
end
```

The default queue name is `chewy`, you can customize it in settings: `sidekiq.queue_name`
```
Chewy.settings[:sidekiq] = {queue: :low}
```

Explicit call of the reindex using `:delayed_sidekiq strategy`
```ruby
CitiesIndex.import([1, 2, 3], strategy: :delayed_sidekiq)
```

Explicit call of the reindex using `:delayed_sidekiq` strategy with `:update_fields` support
```ruby
CitiesIndex.import([1, 2, 3], update_fields: [:name], strategy: :delayed_sidekiq)
```

While running tests with delayed_sidekiq strategy and Sidekiq is using a real redis instance that is NOT cleaned up in between tests (via e.g. `Sidekiq.redis(&:flushdb)`), you'll want to cleanup some redis keys in between tests to avoid state leaking and flaky tests. Chewy provides a convenience method for that:
```ruby
# it might be a good idea to also add to your testing setup, e.g.: a rspec `before` hook
Chewy::Strategy::DelayedSidekiq.clear_timechunks!
```

#### `:active_job`

This does the same thing as `:atomic`, but using ActiveJob. This will inherit the ActiveJob configuration settings including the `active_job.queue_adapter` setting for the environment. Patch `Chewy::Strategy::ActiveJob::Worker` for index updates improving.

```ruby
Chewy.strategy(:active_job) do
  City.popular.map(&:do_some_update_action!)
end
```

The default queue name is `chewy`, you can customize it in settings: `active_job.queue_name`
```
Chewy.settings[:active_job] = {queue: :low}
```

#### `:urgent`

The following strategy is convenient if you are going to update documents in your index one by one.

```ruby
Chewy.strategy(:urgent) do
  City.popular.map(&:do_some_update_action!)
end
```

This code will perform `City.popular.count` requests for ES documents update.

It is convenient for use in e.g. the Rails console with non-block notation:

```ruby
> Chewy.strategy(:urgent)
> City.popular.map(&:do_some_update_action!)
```

#### `:bypass`

When the bypass strategy is active the index will not be automatically updated on object save.

For example, on `City.first.save!` the cities index would not be updated.

#### Nesting

Strategies are designed to allow nesting, so it is possible to redefine it for nested contexts.

```ruby
Chewy.strategy(:atomic) do
  city1.do_update!
  Chewy.strategy(:urgent) do
    city2.do_update!
    city3.do_update!
    # there will be 2 update index requests for city2 and city3
  end
  city4..do_update!
  # city1 and city4 will be grouped in one index update request
end
```

#### Non-block notation

It is possible to nest strategies without blocks:

```ruby
Chewy.strategy(:urgent)
city1.do_update! # index updated
Chewy.strategy(:bypass)
city2.do_update! # update bypassed
Chewy.strategy.pop
city3.do_update! # index updated again
```

#### Designing your own strategies

See [strategy/base.rb](lib/chewy/strategy/base.rb) for more details. See [strategy/atomic.rb](lib/chewy/strategy/atomic.rb) for an example.

### Rails application strategies integration

There are a couple of predefined strategies for your Rails application. Initially, the Rails console uses the `:urgent` strategy by default, except in the sandbox case. When you are running sandbox it switches to the `:bypass` strategy to avoid polluting the index.

Migrations are wrapped with the `:bypass` strategy. Because the main behavior implies that indices are reset after migration, there is no need for extra index updates. Also indexing might be broken during migrations because of the outdated schema.

Controller actions are wrapped with the configurable value of `Chewy.request_strategy` and defaults to `:atomic`. This is done at the middleware level to reduce the number of index update requests inside actions.

It is also a good idea to set up the `:bypass` strategy inside your test suite and import objects manually only when needed, and use `Chewy.massacre` when needed to flush test ES indices before every example. This will allow you to minimize unnecessary ES requests and reduce overhead.

```ruby
RSpec.configure do |config|
  config.before(:suite) do
    Chewy.strategy(:bypass)
  end
end
```

### Elasticsearch client options

All connection options, except the `:prefix`, are passed to the `Elasticseach::Client.new` ([chewy/lib/chewy.rb](https://github.com/toptal/chewy/blob/f5bad9f83c21416ac10590f6f34009c645062e89/lib/chewy.rb#L153-L160)):

Here's the relevant Elasticsearch documentation on the subject: https://rubydoc.info/gems/elasticsearch-transport#setting-hosts

### `ActiveSupport::Notifications` support

Chewy has notifying the following events:

#### `search_query.chewy` payload

  * `payload[:index]`: requested index class
  * `payload[:request]`: request hash

#### `import_objects.chewy` payload

  * `payload[:index]`: currently imported index name
  * `payload[:import]`: imports stats, total imported and deleted objects count:

    ```ruby
    {index: 30, delete: 5}
    ```

  * `payload[:errors]`: might not exist. Contains grouped errors with objects ids list:

    ```ruby
    {index: {
      'error 1 text' => ['1', '2', '3'],
      'error 2 text' => ['4']
    }, delete: {
      'delete error text' => ['10', '12']
    }}
    ```

### NewRelic integration

To integrate with NewRelic you may use the following example source (config/initializers/chewy.rb):

```ruby
require 'new_relic/agent/instrumentation/evented_subscriber'

class ChewySubscriber < NewRelic::Agent::Instrumentation::EventedSubscriber
  def start(name, id, payload)
    event = ChewyEvent.new(name, Time.current, nil, id, payload)
    push_event(event)
  end

  def finish(_name, id, _payload)
    pop_event(id).finish
  end

  class ChewyEvent < NewRelic::Agent::Instrumentation::Event
    OPERATIONS = {
      'import_objects.chewy' => 'import',
      'search_query.chewy' => 'search',
      'delete_query.chewy' => 'delete'
    }.freeze

    def initialize(*args)
      super
      @segment = start_segment
    end

    def start_segment
      segment = NewRelic::Agent::Transaction::DatastoreSegment.new product, operation, collection, host, port
      if (txn = state.current_transaction)
        segment.transaction = txn
      end
      segment.notice_sql @payload[:request].to_s
      segment.start
      segment
    end

    def finish
      if (txn = state.current_transaction)
        txn.add_segment @segment
      end
      @segment.finish
    end

    private

    def state
      @state ||= NewRelic::Agent::TransactionState.tl_get
    end

    def product
      'Elasticsearch'
    end

    def operation
      OPERATIONS[name]
    end

    def collection
      payload.values_at(:type, :index)
             .reject { |value| value.try(:empty?) }
             .first
             .to_s
    end

    def host
      Chewy.client.transport.hosts.first[:host]
    end

    def port
      Chewy.client.transport.hosts.first[:port]
    end
  end
end

ActiveSupport::Notifications.subscribe(/.chewy$/, ChewySubscriber.new)
```

### Search requests

Quick introduction.

#### Composing requests

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

An important part of requests manipulation is merging. There are 4 methods to perform it: `merge`, `and`, `or`, `not`. See [Chewy::Search::QueryProxy](lib/chewy/search/query_proxy.rb) for details. Also, `only` and `except` methods help to remove unneeded parts of the request.

Every other request part is covered by a bunch of additional methods, see [Chewy::Search::Request](lib/chewy/search/request.rb) for details:

```ruby
CitiesIndex.limit(10).offset(30).order(:name, {population: {order: :desc}})
```

Request DSL also provides additional scope actions, like `delete_all`, `exists?`, `count`, `pluck`, etc.

#### Pagination

The request DSL supports pagination with `Kaminari`. An extension is enabled on initialization if `Kaminari` is available. See [Chewy::Search](lib/chewy/search.rb) and [Chewy::Search::Pagination::Kaminari](lib/chewy/search/pagination/kaminari.rb) for details.

#### Named scopes

Chewy supports named scopes functionality. There is no specialized DSL for named scopes definition, it is simply about defining class methods.

See [Chewy::Search::Scoping](lib/chewy/search/scoping.rb) for details.

#### Scroll API

ElasticSearch scroll API is utilized by a bunch of methods: `scroll_batches`, `scroll_hits`, `scroll_wrappers` and `scroll_objects`.

See [Chewy::Search::Scrolling](lib/chewy/search/scrolling.rb) for details.

#### Loading objects

It is possible to load ORM/ODM source objects with the `objects` method. To provide additional loading options use `load` method:

```ruby
CitiesIndex.load(scope: -> { active }).to_a # to_a returns `Chewy::Index` wrappers.
CitiesIndex.load(scope: -> { active }).objects # An array of AR source objects.
```

See [Chewy::Search::Loader](lib/chewy/search/loader.rb) for more details.

In case when it is necessary to iterate through both of the wrappers and objects simultaneously, `object_hash` method helps a lot:

```ruby
scope = CitiesIndex.load(scope: -> { active })
scope.each do |wrapper|
  scope.object_hash[wrapper]
end
```

### Rake tasks

For a Rails application, some index-maintaining rake tasks are defined.

#### `chewy:reset`

Performs zero-downtime reindexing as described [here](https://www.elastic.co/blog/changing-mapping-with-zero-downtime). So the rake task creates a new index with unique suffix and then simply aliases it to the common index name. The previous index is deleted afterwards (see `Chewy::Index.reset!` for more details).

```bash
rake chewy:reset # resets all the existing indices
rake chewy:reset[users] # resets UsersIndex only
rake chewy:reset[users,cities] # resets UsersIndex and CitiesIndex
rake chewy:reset[-users,cities] # resets every index in the application except specified ones
```

#### `chewy:upgrade`

Performs reset exactly the same way as `chewy:reset` does, but only when the index specification (setting or mapping) was changed.

It works only when index specification is locked in `Chewy::Stash::Specification` index. The first run will reset all indexes and lock their specifications.

See [Chewy::Stash::Specification](lib/chewy/stash.rb) and [Chewy::Index::Specification](lib/chewy/index/specification.rb) for more details.


```bash
rake chewy:upgrade # upgrades all the existing indices
rake chewy:upgrade[users] # upgrades UsersIndex only
rake chewy:upgrade[users,cities] # upgrades UsersIndex and CitiesIndex
rake chewy:upgrade[-users,cities] # upgrades every index in the application except specified ones
```

#### `chewy:update`

It doesn't create indexes, it simply imports everything to the existing ones and fails if the index was not created before.

```bash
rake chewy:update # updates all the existing indices
rake chewy:update[users] # updates UsersIndex only
rake chewy:update[users,cities] # updates UsersIndex and CitiesIndex
rake chewy:update[-users,cities] # updates every index in the application except UsersIndex and CitiesIndex
```

#### `chewy:sync`

Provides a way to synchronize outdated indexes with the source quickly and without doing a full reset. By default field `updated_at` is used to find outdated records, but this could be customized by `outdated_sync_field` as described at [Chewy::Index::Syncer](lib/chewy/index/syncer.rb).

Arguments are similar to the ones taken by `chewy:update` task.

See [Chewy::Index::Syncer](lib/chewy/index/syncer.rb) for more details.

```bash
rake chewy:sync # synchronizes all the existing indices
rake chewy:sync[users] # synchronizes UsersIndex only
rake chewy:sync[users,cities] # synchronizes UsersIndex and CitiesIndex
rake chewy:sync[-users,cities] # synchronizes every index in the application except except UsersIndex and CitiesIndex
```

#### `chewy:deploy`

This rake task is especially useful during the production deploy. It is a combination of `chewy:upgrade` and `chewy:sync` and the latter is called only for the indexes that were not reset during the first stage.

It is not possible to specify any particular indexes for this task as it doesn't make much sense.

Right now the approach is that if some data had been updated, but index definition was not changed (no changes satisfying the synchronization algorithm were done), it would be much faster to perform manual partial index update inside data migrations or even manually after the deploy.

Also, there is always full reset alternative with `rake chewy:reset`.

#### `chewy:create_missing_indexes`

This rake task creates newly defined indexes in ElasticSearch and skips existing ones. Useful for production-like environments.

#### Parallelizing rake tasks

Every task described above has its own parallel version. Every parallel rake task takes the number for processes for execution as the first argument and the rest of the arguments are exactly the same as for the non-parallel task version.

[https://github.com/grosser/parallel](https://github.com/grosser/parallel) gem is required to use these tasks.

If the number of processes is not specified explicitly - `parallel` gem tries to automatically derive the number of processes to use.

```bash
rake chewy:parallel:reset
rake chewy:parallel:upgrade[4]
rake chewy:parallel:update[4,cities]
rake chewy:parallel:sync[4,-users]
rake chewy:parallel:deploy[4] # performs parallel upgrade and parallel sync afterwards
```

#### `chewy:journal`

This namespace contains two tasks for the journal manipulations: `chewy:journal:apply` and `chewy:journal:clean`. Both are taking time as the first argument (optional for clean) and a list of indexes exactly as the tasks above. Time can be in any format parsable by ActiveSupport.

```bash
rake chewy:journal:apply["$(date -v-1H -u +%FT%TZ)"] # apply journaled changes for the past hour
rake chewy:journal:apply["$(date -v-1H -u +%FT%TZ)",users] # apply journaled changes for the past hour on UsersIndex only
```

When the size of the journal becomes very large, the classical way of deletion would be obstructive and resource consuming. Fortunately, Chewy internally uses [delete-by-query](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/docs-delete-by-query.html#docs-delete-by-query-task-api) ES function which supports async execution with batching and [throttling](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-delete-by-query.html#docs-delete-by-query-throttle).

The available options, which can be set by ENV variables, are listed below:
* `WAIT_FOR_COMPLETION` - a boolean flag. It controls async execution. It waits by default. When set to `false` (`0`, `f`, `false` or `off` in any case spelling is accepted as `false`), Elasticsearch performs some preflight checks, launches the request, and returns a task reference you can use to cancel the task or get its status.
* `REQUESTS_PER_SECOND` - float. The throttle for this request in sub-requests per second. No throttling is enforced by default.
* `SCROLL_SIZE` - integer. The number of documents to be deleted in single sub-request. The default batch size is 1000.

```bash
rake chewy:journal:clean WAIT_FOR_COMPLETION=false REQUESTS_PER_SECOND=10 SCROLL_SIZE=5000
```

### RSpec integration

Just add `require 'chewy/rspec'` to your spec_helper.rb and you will get additional features:

[update_index](lib/chewy/rspec/update_index.rb) helper
`mock_elasticsearch_response` helper to mock elasticsearch response
`mock_elasticsearch_response_sources` helper to mock elasticsearch response sources
`build_query` matcher to compare request and expected query (returns `true`/`false`)

To use `mock_elasticsearch_response` and `mock_elasticsearch_response_sources` helpers add `include Chewy::Rspec::Helpers` to your tests.

See [chewy/rspec/](lib/chewy/rspec/) for more details.

### Minitest integration

Add `require 'chewy/minitest'` to your test_helper.rb, and then for tests which you'd like indexing test hooks, `include Chewy::Minitest::Helpers`.

Since you can set `:bypass` strategy for test suites and manually handle import for the index and manually flush test indices using `Chewy.massacre`. This will help reduce unnecessary ES requests

But if you require chewy to index/update model regularly in your test suite then you can specify `:urgent` strategy for documents indexing. Add `Chewy.strategy(:urgent)` to test_helper.rb.

Also, you can use additional helpers:

`mock_elasticsearch_response` to mock elasticsearch response
`mock_elasticsearch_response_sources` to mock elasticsearch response sources
`assert_elasticsearch_query` to compare request and expected query (returns `true`/`false`)

See [chewy/minitest/](lib/chewy/minitest/) for more details.

### DatabaseCleaner

If you use `DatabaseCleaner` in your tests with [the `transaction` strategy](https://github.com/DatabaseCleaner/database_cleaner#how-to-use), you may run into the problem that `ActiveRecord`'s models are not indexed automatically on save despite the fact that you set the callbacks to do this with the `update_index` method. The issue arises because `chewy` indices data on `after_commit` run as default, but all `after_commit` callbacks are not run with the `DatabaseCleaner`'s' `transaction` strategy. You can solve this issue by changing the `Chewy.use_after_commit_callbacks` option. Just add the following initializer in your Rails application:

```ruby
#config/initializers/chewy.rb
Chewy.use_after_commit_callbacks = !Rails.env.test?
```

## Contributing

1. Fork it (http://github.com/toptal/chewy/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Implement your changes, cover it with specs and make sure old specs are passing
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request

Use the following Rake tasks to control the Elasticsearch cluster while developing, if you prefer native Elasticsearch installation over the dockerized one:

```bash
rake elasticsearch:start # start Elasticsearch cluster on 9250 port for tests
rake elasticsearch:stop # stop Elasticsearch
```

## Copyright

Copyright (c) 2013-2021 Toptal, LLC. See [LICENSE.txt](LICENSE.txt) for
further details.

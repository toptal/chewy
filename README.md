[![Gem Version](https://badge.fury.io/rb/chewy.svg)](http://badge.fury.io/rb/chewy)
[![Build Status](https://travis-ci.org/toptal/chewy.svg)](https://travis-ci.org/toptal/chewy)
[![Code Climate](https://codeclimate.com/github/toptal/chewy.svg)](https://codeclimate.com/github/toptal/chewy)
[![Inline docs](http://inch-ci.org/github/toptal/chewy.svg?branch=master)](http://inch-ci.org/github/toptal/chewy)

<p align="right">Sponsored by</p>
<p align="right"><a href="https://www.toptal.com/"><img src="https://www.toptal.com/assets/public/blocks/logo/big.png" alt="Toptal" width="105" height="34"></a></p>

# Chewy

Chewy is an ODM and wrapper for [the official Elasticsearch client](https://github.com/elastic/elasticsearch-ruby).

## Table of Contents

* [Why Chewy?](#why-chewy)
* [Installation](#installation)
* [Usage](#usage)
  * [Client settings](#client-settings)
    * [AWS ElasticSearch configuration](#aws-elastic-search)
  * [Index definition](#index-definition)
  * [Type default import options](#type-default-import-options)
  * [Multi (nested) and object field types](#multi-nested-and-object-field-types)
  * [Geo Point fields](#geo-point-fields)
  * [Crutches™ technology](#crutches-technology)
  * [Witchcraft™ technology](#witchcraft-technology)
  * [Raw Import](#raw-import)
  * [Index creation during import](#index-creation-during-import)
  * [Journaling](#journaling)
  * [Types access](#types-access)
  * [Index manipulation](#index-manipulation)
  * [Index update strategies](#index-update-strategies)
    * [Nesting](#nesting)
    * [Non-block notation](#non-block-notation)
    * [Designing your own strategies](#designing-your-own-strategies)
  * [Rails application strategies integration](#rails-application-strategies-integration)
  * [ActiveSupport::Notifications support](#activesupport-notifications-support)
  * [NewRelic integration](#newrelic-integration)
  * [Search requests](#search-requests)
    * [Composing requests](#composing-requests)
    * [Pagination](#pagination)
    * [Named scopes](#named-scopes)
    * [Scroll API](#scroll-api)
    * [Loading objects](#loading-objects)
    * [Legacy DSL incompatibilities](#legacy-dsl-incompatibilities)
  * [Rake tasks](#rake-tasks)
    * [chewy:update and chewy:reset](#chewyupdate-and-chewyreset)
    * [chewy:deploy](#chewydeploy)
  * [Rspec integration](#rspec-integration)
  * [Minitest integration](#minitest-integration)
* [TODO a.k.a coming soon](#todo-aka-coming-soon)
* [Contributing](#contributing)

## Why Chewy?

* Multi-model indices.

  Index classes are independent from ORM/ODM models. Now, implementing e.g. cross-model autocomplete is much easier. You can just define the index and work with it in an object-oriented style. You can define several types for index - one per indexed model.

* Every index is observable by all the related models.

  Most of the indexed models are related to other and sometimes it is necessary to denormalize this related data and put at the same object. For example, you need to index an array of tags together with an article. Chewy allows you to specify an updateable index for every model separately - so corresponding articles will be reindexed on any tag update.

* Bulk import everywhere.

  Chewy utilizes the bulk ES API for full reindexing or index updates. It also uses atomic updates. All the changed objects are collected inside the atomic block and the index is updated once at the end with all the collected objects. See `Chewy.strategy(:atomic)` for more details.

* Powerful querying DSL.

  Chewy has an ActiveRecord-style query DSL. It is chainable, mergeable and lazy, so you can produce queries in the most efficient way. It also has object-oriented query and filter builders.

* Support for ActiveRecord, [Mongoid](https://github.com/mongoid/mongoid) and [Sequel](https://github.com/jeremyevans/sequel).


## Installation

Add this line to your application's Gemfile:

    gem 'chewy'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install chewy

## Usage

### Client settings

There are two ways to configure the Chewy client: the `Chewy.settings` hash and `chewy.yml`

You can create this file manually or run `rails g chewy:install`.

```ruby
# config/initializers/chewy.rb
Chewy.settings = {host: 'localhost:9250'} # do not use environments
```

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

#### Aws Elastic Search
If you would like to use AWS's ElasticSearch using an IAM user policy, you will need to sign your requests for the `es:*` action by injecting the appropriate headers passing a proc to `transport_options`.

```ruby
 Chewy.settings = {
    host: 'http://my-es-instance-on-aws.us-east-1.es.amazonaws.com:80',
    transport_options: {
      headers: { content_type: 'application/json' },
      proc: -> (f) do
          f.request :aws_signers_v4,
                    service_name: 'es',
                    region: 'us-east-1',
                    credentials: Aws::Credentials.new(
                      ENV['AWS_ACCESS_KEY'],
                      ENV['AWS_SECRET_ACCESS_KEY'])
      end
    }
  }
  ```

### Index definition

1. Create `/app/chewy/users_index.rb`

  ```ruby
  class UsersIndex < Chewy::Index

  end
  ```

2. Add one or more types mapping

  ```ruby
  class UsersIndex < Chewy::Index
    define_type User.active # or just model instead_of scope: define_type User
  end
  ```

  Newly-defined index type class is accessible via `UsersIndex.user` or `UsersIndex::User`

3. Add some type mappings

  ```ruby
  class UsersIndex < Chewy::Index
    define_type User.active.includes(:country, :badges, :projects) do
      field :first_name, :last_name # multiple fields without additional options
      field :email, analyzer: 'email' # Elasticsearch-related options
      field :country, value: ->(user) { user.country.name } # custom value proc
      field :badges, value: ->(user) { user.badges.map(&:name) } # passing array values to index
      field :projects do # the same block syntax for multi_field, if `:type` is specified
        field :title
        field :description # default data type is `string`
        # additional top-level objects passed to value proc:
        field :categories, value: ->(project, user) { project.categories.map(&:name) if user.active? }
      end
      field :rating, type: 'integer' # custom data type
      field :created, type: 'date', include_in_all: false,
        value: ->{ created_at } # value proc for source object context
    end
  end
  ```

  [See here for mapping definitions](https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping.html).

4. Add some index- and type-related settings. Analyzer repositories might be used as well. See `Chewy::Index.settings` docs for details:

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

    define_type User.active.includes(:country, :badges, :projects) do
      root date_detection: false do
        template 'about_translations.*', type: 'string', analyzer: 'standard'

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
  end
  ```

  [See index settings here](https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-update-settings.html).
  [See root object settings here](https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-root-object-type.html).

  See [mapping.rb](lib/chewy/type/mapping.rb) for more details.

5. Add model-observing code

  ```ruby
  class User < ActiveRecord::Base
    update_index('users#user') { self } # specifying index, type and back-reference
                                        # for updating after user save or destroy
  end

  class Country < ActiveRecord::Base
    has_many :users

    update_index('users#user') { users } # return single object or collection
  end

  class Project < ActiveRecord::Base
    update_index('users#user') { user if user.active? } # you can return even `nil` from the back-reference
  end

  class Badge < ActiveRecord::Base
    has_and_belongs_to_many :users

    update_index('users') { users } # if index has only one type
                                    # there is no need to specify updated type
  end

  class Book < ActiveRecord::Base
    update_index(->(book) {"books#book_#{book.language}"}) { self } # dynamic index and type with proc.
                                                                    # For book with language == "en"
                                                                    # this code will generate `books#book_en`
  end
  ```

  Also, you can use the second argument for method name passing:

  ```ruby
  update_index('users#user', :self)
  update_index('users#user', :users)
  ```

  In the case of a belongs_to association you may need to update both associated objects, previous and current:

  ```ruby
  class City < ActiveRecord::Base
    belongs_to :country

    update_index('cities#city') { self }
    update_index 'countries#country' do
      # For the latest active_record changed values are
      # already in `previous_changes` hash,
      # but for mongoid you have to use `changes` hash
      previous_changes['country_id'] || country
    end
  end
  ```

  You can observe Sequel models in the same way as ActiveRecord:

  ```ruby
  class User < Sequel::Model
    update_index('users#user') { self }
  end
  ```

  However, to make it work, you must load the chewy plugin into Sequel model:

  ```ruby
  Sequel::Model.plugin :chewy_observe  # for all models, or...
  User.plugin :chewy_observe           # just for User
  ```

### Type default import options

Every type has `default_import_options` configuration to specify, suddenly, default import options:

```ruby
class ProductsIndex < Chewy::Index
  define_type Post.includes(:tags) do
    default_import_options batch_size: 100, bulk_size: 10.megabytes, refresh: false

    field :name
    field :tags, value: -> { tags.map(&:name) }
  end
end
```

See [import.rb](lib/chewy/type/import.rb) for available options.

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
field :full_name, type: 'string', value: ->{ full_name.strip } do
  field :ordered, analyzer: 'ordered'
  field :untouched, index: 'not_analyzed'
end
```

The `value:` option for internal fields will no longer be effective.

### Geo Point fields

You can use [Elasticsearch's geo mapping](https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping-geo-point-type.html) with the `geo_point` field type, allowing you to query, filter and order by latitude and longitude. You can use the following hash format:

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

### Crutches™ technology

Assume you are defining your index like this (product has_many categories through product_categories):

```ruby
class ProductsIndex < Chewy::Index
  define_type Product.includes(:categories) do
    field :name
    field :category_names, value: ->(product) { product.categories.map(&:name) } # or shorter just -> { categories.map(&:name) }
  end
end
```

Then the Chewy reindexing flow will look like the following pseudo-code (even in Mongoid):

```ruby
Product.includes(:categories).find_in_batches(1000) do |batch|
  bulk_body = batch.map do |object|
    {name: object.name, category_names: object.categories.map(&:name)}.to_json
  end
  # here we are sending every batch of data to ES
  Chewy.client.bulk bulk_body
end
```

But in Rails 4.1 and 4.2 you may face a problem with slow associations (take a look at https://github.com/rails/rails/pull/19423). Also, there might be really complicated cases when associations are not applicable.

Then you can replace Rails associations with Chewy Crutches™ technology:

```ruby
class ProductsIndex < Chewy::Index
  define_type Product do
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
    field :category_names, value: ->(product, crutches) { crutches.categories[product.id] }
  end
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

One more experimental technology to increase import performance. As far as you know, chewy defines value proc for every imported field in mapping, so at the import time each of this procs is executed on imported object to extract result document to import. It would be great for performance to use one huge whole-document-returning proc instead. So basically the idea or Witchcraft™ technology is to compile a single document-returning proc from the type definition.

```ruby
define_type Product do
  witchcraft!

  field :title
  field :tags, value: -> { tags.map(&:name) }
  field :categories do
    field :name, value: -> (product, category) { category.name }
    field :type, value: -> (product, category, crutch) { crutch.types[category.name] }
  end
end
```

The type definition above will be compiled to something close to:

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

However, it is quite possible that your type definition will be supported by Witchcraft™ technology out of the box in the most of the cases.

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

define_type Product do
  default_import_options raw_import: ->(hash) {
    LightweightProduct.new(hash)
  }

  field :created_at, 'datetime'
end
```

Also, you can pass `:raw_import` option to the `import` method explicitly.

### Index creation during import

By default, when you perform import Chewy checks whether an index exists and creates it if it's absent.
You can turn off this feature to decrease Elasticsearch hits count.
To do so you need to set `skip_index_creation_on_import` parameter to `false` in your `config/chewy.yml`


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
  "type_name": "...",
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
  define_type City do
    default_import_options journal: true
  end
end
```

You may be wondering why do you need it? The answer is simple: Not to lose the data.
Imagine that:
You reset your index in Zero Downtime manner (to separate index), and meantime somebody keeps updating the data frequently (to old index). So all these actions will be written to the journal index and you'll be able to apply them after index reset with `Chewy::Journal::Apply.since(1.hour.ago.to_i)`.

For index reset journaling is turned off even if you set `journal: true` in `config/chewy.yml` or in `default_import_options`.
You can change it only if you pass `journal: true` parameter explicitly to `#import`.

### Types access

You can access index-defined types with the following API:

```ruby
UsersIndex::User # => UsersIndex::User
UsersIndex.type_hash['user'] # => UsersIndex::User
UsersIndex.type('user') # => UsersIndex::User
UsersIndex.type('foo') # => raises error UndefinedType("Unknown type in UsersIndex: foo")
UsersIndex.types # => [UsersIndex::User]
UsersIndex.type_names # => ['user']
```

### Index manipulation

```ruby
UsersIndex.delete # destroy index if it exists
UsersIndex.delete!

UsersIndex.create
UsersIndex.create! # use bang or non-bang methods

UsersIndex.purge
UsersIndex.purge! # deletes then creates index

UsersIndex::User.import # import with 0 arguments process all the data specified in type definition
                        # literally, User.active.includes(:country, :badges, :projects).find_in_batches
UsersIndex::User.import User.where('rating > 100') # or import specified users scope
UsersIndex::User.import User.where('rating > 100').to_a # or import specified users array
UsersIndex::User.import [1, 2, 42] # pass even ids for import, it will be handled in the most effective way
UsersIndex::User.import User.where('rating > 100'), fields: [:email] # if fields are specified - it will update their values only with the `update` bulk action.

UsersIndex.import # import every defined type
UsersIndex.import user: User.where('rating > 100') # import only active users to `user` type.
  # Other index types, if exists, will be imported with default scope from the type definition.
UsersIndex.reset! # purges index and imports default data for all types
```

If the passed user is `#destroyed?`, or satisfies a `delete_if` type option, or the specified id does not exist in the database, import will perform delete from index action for this object.

```ruby
define_type User, delete_if: :deleted_at
define_type User, delete_if: -> { deleted_at }
define_type User, delete_if: ->(user) { user.deleted_at }
```

See [actions.rb](lib/chewy/index/actions.rb) for more details.

### Index update strategies

Assume you've got the following code:

```ruby
class City < ActiveRecord::Base
  update_index 'cities#city', :self
end

class CitiesIndex < Chewy::Index
  define_type City do
    field :name
  end
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

#### `:resque`

This does the same thing as `:atomic`, but asynchronously using resque. The default queue name is `chewy`. Patch `Chewy::Strategy::Resque::Worker` for index updates improving.

```ruby
Chewy.strategy(:resque) do
  City.popular.map(&:do_some_update_action!)
end
```

#### `:sidekiq`

This does the same thing as `:atomic`, but asynchronously using sidekiq. Patch `Chewy::Strategy::Sidekiq::Worker` for index updates improving.

```ruby
Chewy.strategy(:sidekiq) do
  City.popular.map(&:do_some_update_action!)
end
```

#### `:active_job`

This does the same thing as `:atomic`, but using ActiveJob. This will inherit the ActiveJob configuration settings including the `active_job.queue_adapter` setting for the environment. Patch `Chewy::Strategy::ActiveJob::Worker` for index updates improving.

```ruby
Chewy.strategy(:active_job) do
  City.popular.map(&:do_some_update_action!)
end
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

The bypass strategy simply silences index updates.

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

### `ActiveSupport::Notifications` support

Chewy has notifying the following events:

#### `search_query.chewy` payload

  * `payload[:index]`: requested index class
  * `payload[:request]`: request hash

#### `import_objects.chewy` payload

  * `payload[:type]`: currently imported type
  * `payload[:import]`: imports stats, total imported and deleted objects count:

    ```ruby
    {index: 30, delete: 5}
    ```

  * `payload[:errors]`: might not exists. Contains grouped errors with objects ids list:

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
ActiveSupport::Notifications.subscribe('import_objects.chewy') do |name, start, finish, id, payload|
  metric_name = "Database/ElasticSearch/import"
  duration = (finish - start).to_f
  logged = "#{payload[:type]} #{payload[:import].to_a.map{ |i| i.join(':') }.join(', ')}"

  self.class.trace_execution_scoped([metric_name]) do
    NewRelic::Agent.instance.transaction_sampler.notice_sql(logged, nil, duration)
    NewRelic::Agent.instance.sql_sampler.notice_sql(logged, metric_name, nil, duration)
    NewRelic::Agent.record_metric(metric_name, duration)
  end
end

ActiveSupport::Notifications.subscribe('search_query.chewy') do |name, start, finish, id, payload|
  metric_name = "Database/ElasticSearch/search"
  duration = (finish - start).to_f
  logged = "#{payload[:type].presence || payload[:index]} #{payload[:request]}"

  self.class.trace_execution_scoped([metric_name]) do
    NewRelic::Agent.instance.transaction_sampler.notice_sql(logged, nil, duration)
    NewRelic::Agent.instance.sql_sampler.notice_sql(logged, metric_name, nil, duration)
    NewRelic::Agent.record_metric(metric_name, duration)
  end
end
```

### Search requests

Long story short: there is a new DSL that supports ES2 and ES5, the previous DSL version (which supports ES1 and ES2) documentation was moved to [LEGACY_DSL.md](LEGACY_DSL.md).

If you want to use it - simply do `Chewy.search_class = Chewy::Query` somewhere before indices are initialized.

The new DSL is enabled by default, here is a quick introduction.

#### Composing requests

The request DSL have the same chainable nature as AR or Mongoid ones. The main class is `Chewy::Search::Request`. It is possible to perform requests on behalf of indices or types:

```ruby
PlaceIndex.query(match: {name: 'London'}) # returns documents of any type
PlaceIndex::City.query(match: {name: 'London'}) # returns cities only.
```

Main methods of the request DSL are: `query`, `filter` and `post_filter`, it is possible to pass pure query hashes or use `elasticsearch-dsl`. Also, there is an additional

```ruby
PlaceIndex
  .filter(term: {name: 'Bangkok'})
  .query { match name: 'London' }
  .query.not(range: {population: {gt: 1_000_000}})
```

See https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl.html and https://github.com/elastic/elasticsearch-ruby/tree/master/elasticsearch-dsl for more details.

An important part of requests manipulation is merging. There are 4 methods to perform it: `merge`, `and`, `or`, `not`. See [Chewy::Search::QueryProxy](lib/chewy/search/query_proxy.rb) for details. Also, `only` and `except` methods help to remove unneeded parts of the request.

Every other request part is covered by a bunch of additional methods, see [Chewy::Search::Request](lib/chewy/search/request.rb) for details:

```ruby
PlaceIndex.limit(10).offset(30).order(:name, {population: {order: :desc}})
```

Request DSL also provides additional scope actions, like `delete_all`, `exists?`, `count`, `pluck`, etc.

#### Pagination

The request DSL supports pagination with `Kaminari` and `WillPaginate`. An appropriate extension is enabled on initializtion if any of libraries is available. See [Chewy::Search](lib/chewy/search.rb) and [Chewy::Search::Pagination](lib/chewy/search/pagination/) namespace for details.

#### Named scopes

Chewy supports named scopes functionality. There is no specialized DSL for named scopes definition, it is simply about defining class methods.

See [Chewy::Search::Scoping](lib/chewy/search/scoping.rb) for details.

#### Scroll API

ElasticSearch scroll API is utilized by a bunch of methods: `scroll_batches`, `scroll_hits`, `scroll_wrappers` and `scroll_objects`.

See [Chewy::Search::Scrolling](lib/chewy/search/scrolling.rb) for details.

#### Loading objects

It is possible to load ORM/ODM source objects with the `objects` method. To provide additional loading options use `load` method:

```ruby
PlacesIndex.load(scope: -> { active }).to_a # to_a returns `Chewy::Type` wrappers.
PlacesIndex.load(scope: -> { active }).objects # An array of AR source objects.
```

See [Chewy::Search::Loader](lib/chewy/search/loader.rb) for more details.

In case when it is necessary to iterate through both of the wrappers and objects simultaneously, `object_hash` method helps a lot:

```ruby
scope = PlacesIndex.load(scope: -> { active })
scope.each do |wrapper|
  scope.object_hash[wrapper]
end
```

#### Legacy DSL incompatibilities

* Filters advanced block DSL is not supported anymore, `elasticsearch-dsl` is used instead.
* Things like `query_mode` and `filter_mode` are in past, use advanced DSL to achieve similar behavior. See [Chewy::Search::QueryProxy](lib/chewy/search/query_proxy.rb) for details.
* `preload` method is no more, the collection returned by scope doesn't depend on loading options, scope always returns `Chewy::Type` wrappers. To get ORM/ODM objects, use `#objects` method.
* Some of the methods have changed their purpose: `only` was used to filter fields before, now it filters the scope. To filter fields use `source` or `stored_fields`.
* `types!` method is no more, use `except(:types).types(...)`
* Named aggregations are not supported, use named scopes instead.
* A lot of query-level methods were not ported: everything that is related to boost and scoring. Use `query` manipulation to provide them.
* `Chewy::Type#_object` returns nil always. Use `Chewy::Search::Response#object_hash` instead.

### Rake tasks

#### `chewy:update` and `chewy:reset`

Inside the Rails application, some index-maintaining rake tasks are defined.

```bash
rake chewy:reset # resets all the existing indices, declared in app/chewy
rake chewy:reset[users] # resets UsersIndex only
rake chewy:reset[users,projects] # resets UsersIndex and ProjectsIndex
rake chewy:reset[-users,projects] # resets every index in application except specified ones

rake chewy:update # updates all the existing indices, declared in app/chewy
rake chewy:update[users] # updates UsersIndex only
rake chewy:update[users,projects] # updates UsersIndex and ProjectsIndex
rake chewy:update[-users,projects] # updates every index in application except specified ones

```

`rake chewy:reset` performs zero-downtime reindexing as described [here](https://www.elastic.co/blog/changing-mapping-with-zero-downtime). So basically rake task creates a new index with uniq suffix and then simply aliases it to the common index name. The previous index is deleted afterwards (see `Chewy::Index.reset!` for more details).

#### `chewy:deploy`

This rake task is especially useful during the production deploy. Currently it executes selective reset, this means that an index will be reset only if the index specification (settings or mappings) has been changed, otherwise the reset of this index will be skipped.

Obviously at the first run it will reset everything because it needs to lock all the index specifications in the `Chewy::Stash`.

See [Chewy::Stash](lib/chewy/stash.rb) and [Chewy::Index::Specification](lib/chewy/index/specification.rb) for more details.

In the future, additional routines are planned during `chewy:deploy` execution. Like, additional fast or partial index updates to make sure everything is up-to-date as it was a full reset.

Right now the approach is that if some data had been updated, but index specification had not been changed, it would be much faster to perform manual partial index update inside data migrations or even manually after the deploy.

Also, there is always full reset alternative with `rake chewy:reset`.

### Rspec integration

Just add `require 'chewy/rspec'` to your spec_helper.rb and you will get additional features: See [update_index.rb](lib/chewy/rspec/update_index.rb) for more details.

### Minitest integration

Add `require 'chewy/minitest'` to your test_helper.rb, and then for tests which you'd like indexing test hooks, `include Chewy::Minitest::Helpers`.

### DatabaseCleaner

If you use `DatabaseCleaner` in your tests with [the `transaction` strategy](https://github.com/DatabaseCleaner/database_cleaner#how-to-use), you may run into the problem that `ActiveRecord`'s models are not indexed automatically on save despite the fact that you set the callbacks to do this with the `update_index` method. The issue arises because `chewy` indices data on `after_commit` run as default, but all `after_commit` callbacks are not run with the `DatabaseCleaner`'s' `transaction` strategy. You can solve this issue by changing the `Chewy.use_after_commit_callbacks` option. Just add the following initializer in your Rails application:

```ruby
#config/initializers/chewy.rb
Chewy.use_after_commit_callbacks = !Rails.env.test?
```

## TODO a.k.a coming soon:

* Typecasting support
* update_all support
* Maybe, closer ORM/ODM integration, creating index classes implicitly

## Contributing

1. Fork it (http://github.com/toptal/chewy/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Implement your changes, cover it with specs and make sure old specs are passing
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request

Use the following Rake tasks to control the Elasticsearch cluster while developing.

```bash
rake elasticsearch:start # start Elasticsearch cluster on 9250 port for tests
rake elasticsearch:stop # stop Elasticsearch
```

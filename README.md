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
* [Usage](#usage)
  * [Client settings](#client-settings)
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
  * [Index querying](#index-querying)
  * [Additional query action.](#additional-query-action)
  * [Filters query DSL](#filters-query-dsl)
  * [Faceting](#faceting)
  * [Aggregations](#aggregations)
  * [Script fields](#script-fields)
  * [Script scoring](#script-scoring)
  * [Boost Factor](#boost-factor)
  * [Objects loading](#objects-loading)
    * [NewRelic integration](#newrelic-integration)
  * [Rake tasks](#rake-tasks)
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

The `value:` option for internal fields would no longer be effective.

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

Then the Chewy reindexing flow would look like the following pseudo-code (even in Mongoid):

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

An example flow would look like this:

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
When you create/update/destroy your records, it will be saved in this special index.
If you make something with a batch of records (e.g. during index reset) it will be saved as a one record, including primary keys of each document that was affected.
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

This code would perform `City.popular.count` requests for ES documents update.

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

### Index querying

```ruby
scope = UsersIndex.query(term: {name: 'foo'})
  .filter(range: {rating: {gte: 100}})
  .order(created: :desc)
  .limit(20).offset(100)

scope.to_a # => will produce array of UserIndex::User or other types instances
scope.map { |user| user.email }
scope.total_count # => will return total objects count

scope.per(10).page(3) # supports kaminari pagination
scope.explain.map { |user| user._explanation }
scope.only(:id, :email) # returns ids and emails only

scope.merge(other_scope) # queries could be merged
```

Also, queries can be performed on a type individually:

```ruby
UsersIndex::User.filter(term: {name: 'foo'}) # will return UserIndex::User collection only
```

If you are performing more than one `filter` or `query` in the chain, all the filters and queries will be concatenated in the way specified by
`filter_mode` and `query_mode` respectively.

The default `filter_mode` is `:and` and the default `query_mode` is `bool`.

Available filter modes are: `:and`, `:or`, `:must`, `:should` and any minimum_should_match-acceptable value

Available query modes are: `:must`, `:should`, `:dis_max`, any minimum_should_match-acceptable value or float value for dis_max query with tie_breaker specified.

```ruby
UsersIndex::User.filter{ name == 'Fred' }.filter{ age < 42 } # will be wrapped with `and` filter
UsersIndex::User.filter{ name == 'Fred' }.filter{ age < 42 }.filter_mode(:should) # will be wrapped with bool `should` filter
UsersIndex::User.filter{ name == 'Fred' }.filter{ age < 42 }.filter_mode('75%') # will be wrapped with bool `should` filter with `minimum_should_match: '75%'`
```

See [query.rb](lib/chewy/query.rb) for more details.

### Additional query action.

You may also perform additional actions on the query scope, such as deleting of all the scope documents:

```ruby
UsersIndex.delete_all
UsersIndex::User.delete_all
UsersIndex.filter{ age < 42 }.delete_all
UsersIndex::User.filter{ age < 42 }.delete_all
```

### Filters query DSL

There is a test version of the filter-creating DSL:

```ruby
UsersIndex.filter{ name == 'Fred' } # will produce `term` filter.
UsersIndex.filter{ age <= 42 } # will produce `range` filter.
```

The basis of the DSL is the expression. There are 2 types of expressions:

* Simple function

  ```ruby
  UsersIndex.filter{ s('doc["num"] > 1') } # script expression
  UsersIndex.filter{ q(query_string: {query: 'lazy fox'}) } # query expression
  ```

* Field-dependent composite expression
  Consists of the field name (with or without dot notation), a value, and an action operator between them. The field name might take additional options for passing to the resulting expression.

  ```ruby
  UsersIndex.filter{ name == 'Name' } # simple field term filter
  UsersIndex.filter{ name(:bool) == ['Name1', 'Name2'] } # terms query with `execution: :bool` option passed
  UsersIndex.filter{ answers.title =~ /regexp/ } # regexp filter for `answers.title` field
  ```

You can combine expressions as you wish with the help of combination operators.

```ruby
UsersIndex.filter{ (name == 'Name') & (email == 'Email') } # combination produces `and` filter
UsersIndex.filter{
  must(
    should(name =~ 'Fr').should_not(name == 'Fred') & (age == 42), email =~ /gmail\.com/
  ) | ((roles.admin == true) & name?)
} # many of the combination possibilities
```

There is also a special syntax for cache enabling:

```ruby
UsersIndex.filter{ ~name == 'Name' } # you can apply tilde to the field name
UsersIndex.filter{ ~(name == 'Name') } # or to the whole expression

# if you are applying cache to the one part of range filter
# the whole filter will be cached:
UsersIndex.filter{ ~(age > 42) & (age <= 50) }

# You can pass cache options as a field option also.
UsersIndex.filter{ name(cache: true) == 'Name' }
UsersIndex.filter{ name(cache: false) == 'Name' }

# With regexp filter you can pass _cache_key
UsersIndex.filter{ name(cache: 'name_regexp') =~ /Name/ }
# Or not
UsersIndex.filter{ name(cache: true) =~ /Name/ }
```

Compliance cheatsheet for filters and DSL expressions:

* Term filter

  ```json
  {"term": {"name": "Fred"}}
  {"not": {"term": {"name": "Johny"}}}
  ```

  ```ruby
  UsersIndex.filter{ name == 'Fred' }
  UsersIndex.filter{ name != 'Johny' }
  ```

* Terms filter

  ```json
  {"terms": {"name": ["Fred", "Johny"]}}
  {"not": {"terms": {"name": ["Fred", "Johny"]}}}

  {"terms": {"name": ["Fred", "Johny"], "execution": "or"}}

  {"terms": {"name": ["Fred", "Johny"], "execution": "and"}}

  {"terms": {"name": ["Fred", "Johny"], "execution": "bool"}}

  {"terms": {"name": ["Fred", "Johny"], "execution": "fielddata"}}
  ```

  ```ruby
  UsersIndex.filter{ name == ['Fred', 'Johny'] }
  UsersIndex.filter{ name != ['Fred', 'Johny'] }

  UsersIndex.filter{ name(:|) == ['Fred', 'Johny'] }
  UsersIndex.filter{ name(:or) == ['Fred', 'Johny'] }
  UsersIndex.filter{ name(execution: :or) == ['Fred', 'Johny'] }

  UsersIndex.filter{ name(:&) == ['Fred', 'Johny'] }
  UsersIndex.filter{ name(:and) == ['Fred', 'Johny'] }
  UsersIndex.filter{ name(execution: :and) == ['Fred', 'Johny'] }

  UsersIndex.filter{ name(:b) == ['Fred', 'Johny'] }
  UsersIndex.filter{ name(:bool) == ['Fred', 'Johny'] }
  UsersIndex.filter{ name(execution: :bool) == ['Fred', 'Johny'] }

  UsersIndex.filter{ name(:f) == ['Fred', 'Johny'] }
  UsersIndex.filter{ name(:fielddata) == ['Fred', 'Johny'] }
  UsersIndex.filter{ name(execution: :fielddata) == ['Fred', 'Johny'] }
  ```

* Regexp filter (== and =~ are equivalent)

  ```json
  {"regexp": {"name.first": "s.*y"}}

  {"not": {"regexp": {"name.first": "s.*y"}}}

  {"regexp": {"name.first": {"value": "s.*y", "flags": "ANYSTRING|INTERSECTION"}}}
  ```

  ```ruby
  UsersIndex.filter{ name.first == /s.*y/ }
  UsersIndex.filter{ name.first =~ /s.*y/ }

  UsersIndex.filter{ name.first != /s.*y/ }
  UsersIndex.filter{ name.first !~ /s.*y/ }

  UsersIndex.filter{ name.first(:anystring, :intersection) == /s.*y/ }
  UsersIndex.filter{ name.first(flags: [:anystring, :intersection]) == /s.*y/ }
  ```

* Prefix filter

  ```json
  {"prefix": {"name": "Fre"}}
  {"not": {"prefix": {"name": "Joh"}}}
  ```

  ```ruby
  UsersIndex.filter{ name =~ re' }
  UsersIndex.filter{ name !~ 'Joh' }
  ```

* Exists filter

  ```json
  {"exists": {"field": "name"}}
  ```

  ```ruby
  UsersIndex.filter{ name? }
  UsersIndex.filter{ !!name }
  UsersIndex.filter{ !!name? }
  UsersIndex.filter{ name != nil }
  UsersIndex.filter{ !(name == nil) }
  ```

* Missing filter

  ```json
  {"missing": {"field": "name", "existence": true, "null_value": false}}
  {"missing": {"field": "name", "existence": true, "null_value": true}}
  {"missing": {"field": "name", "existence": false, "null_value": true}}
  ```

  ```ruby
  UsersIndex.filter{ !name }
  UsersIndex.filter{ !name? }
  UsersIndex.filter{ name == nil }
  ```

* Range

  ```json
  {"range": {"age": {"gt": 42}}}
  {"range": {"age": {"gte": 42}}}
  {"range": {"age": {"lt": 42}}}
  {"range": {"age": {"lte": 42}}}

  {"range": {"age": {"gt": 40, "lt": 50}}}
  {"range": {"age": {"gte": 40, "lte": 50}}}

  {"range": {"age": {"gt": 40, "lte": 50}}}
  {"range": {"age": {"gte": 40, "lt": 50}}}
  ```

  ```ruby
  UsersIndex.filter{ age > 42 }
  UsersIndex.filter{ age >= 42 }
  UsersIndex.filter{ age < 42 }
  UsersIndex.filter{ age <= 42 }

  UsersIndex.filter{ age == (40..50) }
  UsersIndex.filter{ (age > 40) & (age < 50) }
  UsersIndex.filter{ age == [40..50] }
  UsersIndex.filter{ (age >= 40) & (age <= 50) }

  UsersIndex.filter{ (age > 40) & (age <= 50) }
  UsersIndex.filter{ (age >= 40) & (age < 50) }
  ```

* Bool filter

  ```json
  {"bool": {
    "must": [{"term": {"name": "Name"}}],
    "should": [{"term": {"age": 42}}, {"term": {"age": 45}}]
  }}
  ```

  ```ruby
  UsersIndex.filter{ must(name == 'Name').should(age == 42, age == 45) }
  ```

* And filter

  ```json
  {"and": [{"term": {"name": "Name"}}, {"range": {"age": {"lt": 42}}}]}
  ```

  ```ruby
  UsersIndex.filter{ (name == 'Name') & (age < 42) }
  ```

* Or filter

  ```json
  {"or": [{"term": {"name": "Name"}}, {"range": {"age": {"lt": 42}}}]}
  ```

  ```ruby
  UsersIndex.filter{ (name == 'Name') | (age < 42) }
  ```

  ```json
  {"not": {"term": {"name": "Name"}}}
  {"not": {"range": {"age": {"lt": 42}}}}
  ```

  ```ruby
  UsersIndex.filter{ !(name == 'Name') } # or UsersIndex.filter{ name != 'Name' }
  UsersIndex.filter{ !(age < 42) }
  ```

* Match all filter

  ```json
  {"match_all": {}}
  ```

  ```ruby
  UsersIndex.filter{ match_all }
  ```

* Has child filter

  ```json
  {"has_child": {"type": "blog_tag", "query": {"term": {"tag": "something"}}}
  {"has_child": {"type": "comment", "filter": {"term": {"user": "john"}}}
  ```

  ```ruby
  UsersIndex.filter{ has_child(:blog_tag).query(term: {tag: 'something'}) }
  UsersIndex.filter{ has_child(:comment).filter{ user == 'john' } }
  ```

* Has parent filter

  ```json
  {"has_parent": {"type": "blog", "query": {"term": {"tag": "something"}}}}
  {"has_parent": {"type": "blog", "filter": {"term": {"text": "bonsai three"}}}}
  ```

  ```ruby
  UsersIndex.filter{ has_parent(:blog).query(term: {tag: 'something'}) }
  UsersIndex.filter{ has_parent(:blog).filter{ text == 'bonsai three' } }
  ```

See [filters.rb](lib/chewy/query/filters.rb) for more details.

### Faceting

Facets are an optional sidechannel you can request from Elasticsearch describing certain fields of the resulting collection. The most common use for facets is to allow the user to continue filtering specifically within the subset, as opposed to the global index.

For instance, let's request the `country` field as a facet along with our users collection. We can do this with the #facets method like so:

```ruby
UsersIndex.filter{ [...] }.facets({countries: {terms: {field: 'country'}}})
```

Let's look at what we asked from Elasticsearch. The facets setter method accepts a hash. You can choose custom/semantic key names for this hash for your own convenience (in this case I used the plural version of the actual field), in our case `countries`. The following nested hash tells ES to grab and aggregate values (terms) from the `country` field on our indexed records.

The response will include the `:facets` sidechannel:

```
< { ... ,"facets":{"countries":{"_type":"terms","missing":?,"total":?,"other":?,"terms":[{"term":"USA","count":?},{"term":"Brazil","count":?}, ...}}
```

### Aggregations

Aggregations are part of the optional sidechannel that can be requested with a query.

You interact with aggregations using the composable #aggregations method (or its alias #aggs)

Let's look at an example.

```ruby
class UsersIndex < Chewy::Index
  define_type User do
    field :name
    field :rating
  end
end

all_johns = UsersIndex::User.filter { name == 'john' }.aggs({ avg_rating: { avg: { field: 'rating' } } })

avg_johns_rating = all_johns.aggs
# => {"avg_rating"=>{"value"=>3.5}}
```

It is convenient to name aggregations that you intend to reuse regularly. This is achieve with the .aggregation method,
which is also available under the .agg alias method.

Here's the same example from before

```ruby
class UsersIndex < Chewy::Index
  define_type User do
    field :name
    field :rating, type: "long"
    agg :avg_rating do
      { avg: { field: 'rating' } }
    end
  end
end

all_johns = UsersIndex::User.filter { name == 'john' }.aggs(:avg_rating)

avg_johns_rating = all_johns.aggs
# => {"avg_rating"=>{"value"=>3.5}}
```

It is possible to run into collisions between named aggregations. This occurs when there is more than one aggregation
 with the same name. To explicitly reference an aggregation you provide a string to the #aggs method of the form:
 `index_name#document_type.aggregation_name`

Consider this example where there are two separate aggregations named `avg_rating`

```ruby
class UsersIndex < Chewy::Index
  define_type User do
    field :name
    field :rating, type: "long"
    agg :avg_rating do
      { avg: { field: 'rating' } }
    end
  end
  define_type Post do
    field :title
    field :body
    field :comments do
      field :message
      field :rating, type: "long"
    end
    agg :avg_rating do
      { avg: { field: 'comments.rating' } }
    end
  end
end

all_docs = UsersIndex.filter {match_all}.aggs("users#user.avg_rating")
all_docs.aggs
# => {"users#user.avg_rating"=>{"value"=>3.5}}
```

### Script fields

Script fields allow you to execute Elasticsearch's scripting languages such as groovy and javascript. More about supported languages and what scripting is [here](https://www.elastic.co/guide/en/elasticsearch/reference/0.90/modules-scripting.html). This feature allows you to calculate the distance between geo points, for example. This is how to use the DSL:

```ruby
UsersIndex.script_fields(
  distance: {
    params: {
      lat: 37.569976,
      lon: -122.351591
    },
    script: "doc['coordinates'].distanceInMiles(lat, lon)"
  }
)
```
Here, `coordinates` is a field with type `geo_point`. There will be a `distance` field for the index's model in the search result.

### Script scoring

Script scoring is used to score the search results. All scores are added to the search request and combined according to boost mode and score mode. This can be useful if, for example, a score function is computationally expensive and it is sufficient to compute the score on a filtered set of documents. For example, you might want to multiply the score by another numeric field in the doc:

```ruby
UsersIndex.script_score("_score * doc['my_numeric_field'].value")
```

### Boost Factor

Boost factors are a way to add a boost to a query where documents match the filter. If you have some users who are experts and some who are regular users, you might want to give the experts a higher score and boost to the top of the search results. You can accomplish this by using the #boost_factor method and adding a boost score of 5 for an expert user:

```ruby
UsersIndex.boost_factor(5, filter: {term: {type: 'Expert'}})
```

### Objects loading

It is possible to load source objects from the database for every search result:

```ruby
scope = UsersIndex.filter(range: {rating: {gte: 100}})

scope.load # => scope is marked to return User instances array
scope.load.query(...) # => since objects are loaded lazily you can complete scope
scope.load(user: { scope: ->{ includes(:country) }}) # you can also pass loading scopes for each
                                                     # possibly returned type
scope.load(user: { scope: User.includes(:country) }) # the second scope passing way.
scope.load(scope: ->{ includes(:country) }) # and more common scope applied to every loaded object type.

scope.only(:id).load # it is optimal to request ids only if you are not planning to use type objects
```

The `preload` method takes the same options as `load` and ORM/ODM objects will be loaded, but the scope will still return an array of Chewy wrappers. To access real objects use the `_object` wrapper method:

```ruby
UsersIndex.filter(range: {rating: {gte: 100}}).preload(...).query(...).map(&:_object)
```

See [loading.rb](lib/chewy/query/loading.rb) for more details.

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

#### NewRelic integration

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

### Rake tasks

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


### Rspec integration

Just add `require 'chewy/rspec'` to your spec_helper.rb and you will get additional features: See [update_index.rb](lib/chewy/rspec/update_index.rb) for more details.

### Minitest integration

Add `require 'chewy/minitest'` to your test_helper.rb, and then for tests which you'd like indexing test hooks, `include Chewy::Minitest::Helpers`.

### DatabaseCleaner

If you use `DatabaseCleaner` in your tests with [the `transaction` strategy](https://github.com/DatabaseCleaner/database_cleaner#how-to-use), you may run into the problem that `ActiveRecord`'s models are not indexed automatically on save despite the fact that you set the callbacks to do this with the `update_index` method. The issue arises because `chewy` indexes data on `after_commit` run as default, but all `after_commit` callbacks are not run with the `DatabaseCleaner`'s' `transaction` strategy. You can solve this issue by changing the `Chewy.use_after_commit_callbacks` option. Just add the following initializer in your Rails application:

```ruby
#config/initializers/chewy.rb
Chewy.use_after_commit_callbacks = !Rails.env.test?
```

## TODO a.k.a coming soon:

* Typecasting support
* Advanced (simplified) query DSL: `UsersIndex.query { email == 'my@gmail.com' }` will produce term query
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

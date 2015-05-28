[![Gem Version](https://badge.fury.io/rb/chewy.svg)](http://badge.fury.io/rb/chewy)
[![Build Status](https://travis-ci.org/toptal/chewy.png)](https://travis-ci.org/toptal/chewy)
[![Code Climate](https://codeclimate.com/github/toptal/chewy.png)](https://codeclimate.com/github/toptal/chewy)
[![Inline docs](http://inch-ci.org/github/toptal/chewy.svg?branch=master)](http://inch-ci.org/github/toptal/chewy)

<p align="right">Sponsored by</p>
<p align="right"><a href="http://www.toptal.com/"><img src="http://www.toptal.com/assets/public/blocks/logo/big.png" alt="Toptal" width="105" height="34"></a></p>

# Chewy

Chewy is ODM and wrapper for official elasticsearch client (https://github.com/elasticsearch/elasticsearch-ruby)

## Why chewy?

* Multi-model indexes.

  Index classes are independent from ORM/ODM models. Now implementing, e.g. cross-model autocomplete is much easier. You can just define index and work with it in object-oriented style. You can define several types for index - one per indexed model.

* Every index is observable by all the related models.

  Most of the indexed models are related to other and sometimes it is nessesary to denormalize this related data and put at the same object. For example, you need to index array of tags with article together. Chewy allows you to specify updatable index for every model separately. So, corresponding articles will be reindexed on any tag update.

* Bulk import everywhere.

  Chewy utilizes bulk ES API for full reindexing or index updates. Also it uses atomic updates concept. All the changed objects are collected inside the atomic block and index is updated once at the end of it with all the collected object. See `Chewy.strategy(:atomic)` for more details.

* Powerful querying DSL.

  Chewy has AR-style query DSL. It is chainable, mergable and lazy. So you can produce queries in the most efficient way. Also it has object-oriented query and filter builders.

## Installation

Add this line to your application's Gemfile:

    gem 'chewy'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install chewy

## Usage

### Client settings

There are 2 ways to configure Chewy client: `Chewy.settings` hash and `chewy.yml`

You can create this file manually or run `rails g chewy:install` to do that with yaml way

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

The result config merges both hashes. Client options are passed as is to Elasticsearch::Transport::Client except the `:prefix` - it is used internally by chewy to create prefixed index names:

```ruby
  Chewy.settings = {prefix: 'test'}
  UsersIndex.index_name # => 'test_users'
```

Also logger might be set explicitly:

```ruby
Chewy.logger = Logger.new
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
      field :email, analyzer: 'email' # elasticsearch-related options
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

  Mapping definitions - http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/mapping.html

4. Add some index- and type-related settings. Analyzers repositories might be used as well. See `Chewy::Index.settings` docs for details:

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
        field :about_translations, type: 'object' # pass object type explicitely if necessary
        field :rating, type: 'integer'
        field :created, type: 'date', include_in_all: false,
          value: ->{ created_at }
      end
    end
  end
  ```

  Index settings - http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/indices-update-settings.html
  Root object settings - http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/mapping-root-object-type.html

  See [mapping.rb](lib/chewy/type/mapping.rb) for more details.

5. Add model observing code

  ```ruby
  class User < ActiveRecord::Base
    update_index('users#user') { self } # specifying index, type and backreference
                                        # for updating after user save or destroy
  end

  class Country < ActiveRecord::Base
    has_many :users

    update_index('users#user') { users } # return single object or collection
  end

  class Project < ActiveRecord::Base
    update_index('users#user') { user if user.active? } # you can return even `nil` from the backreference
  end

  class Badge < ActiveRecord::Base
    has_and_belongs_to_many :users

    update_index('users') { users } # if index has only one type
                                    # there is no need to specify updated type
  end
  ```

  Also, you can use second argument for method name passing:

  ```ruby
  update_index('users#user', :self)
  update_index('users#user', :users)
  ```

  In case of belongs_to association you may need to update both associated objects, previous and current:

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

### Types access

You are able to access index-defined types with the following API:

```ruby
UsersIndex::User # => UsersIndex::User
UsersIndex.type_hash['user'] # => UsersIndex::User
UsersIndex.user # => UsersIndex::User
UsersIndex.types # => [UsersIndex::User]
UsersIndex.type_names # => ['user']
```

### Index manipulation

```ruby
UsersIndex.delete # destroy index if exists
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

Also if passed user is `#destroyed?`, or satisfy `delete_if` type option, or specified id does not exists in the database, import will perform delete from index action for this object.

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

If you'll perform something like `City.first.save!` you'll get
UndefinedUpdateStrategy exception instead of normal object saving
and index update. This exception forces you to choose appropriate
update strategy for current context.

If you want to return behavior was before 0.7.0 - just set
`Chewy.root_strategy = :bypass`.

#### `:atomic`

The main strategy here is `:atomic`. Assume you have to update a
lot of records in db.

```ruby
Chewy.strategy(:atomic) do
  City.popular.map(&:do_some_update_action!)
end
```

Using this strategy delays index update request until the end of
block. Updated records are aggregated and index update happens with
bulk API. So this strategy is highly optimized.

#### `:resque`

Does the same thing as `:atomic`, but in async way using resque.
Default queue name is `chewy`.
Patch `Chewy::Strategy::Resque::Worker` for index updates improving.

```ruby
Chewy.strategy(:resque) do
  City.popular.map(&:do_some_update_action!)
end
```

#### `:sidekiq`

Does the same thing as `:atomic`, but in async way using sidekiq.
Patch `Chewy::Strategy::Sidekiq::Worker` for index updates improving.

```ruby
Chewy.strategy(:sidekiq) do
  City.popular.map(&:do_some_update_action!)
end
```

#### `:urgent`

Next strategy is convenient if you are going to update documents in
index one-by-one.

```ruby
Chewy.strategy(:urgent) do
  City.popular.map(&:do_some_update_action!)
end
```

This code would perform `City.popular.count` requests for ES
documents update.

Seems to be convenient for usage in e.g. rails console with
non-block notation:

```ruby
> Chewy.strategy(:urgent)
> City.popular.map(&:do_some_update_action!)
```

#### `:bypass`

Bypass strategy simply silences index updates.

#### Nesting

Strategies are designed to allow nesting, so it is possible
to redefine it for nested contexts.

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

#### Designing own strategies

See [strategy/base.rb](lib/chewy/strategy/base.rb) for more details.
See [strategy/atomic.rb](lib/chewy/strategy/atomic.rb) for example.

### Rails application strategies integration

There is a couple of pre-defined strategies for your rails application. At first, rails console uses `:urgent` strategy by default, except the sandbox case. When you are running sandbox it switches to `bypass` strategy to avoid index polluting.

Also migrations are wrapped with `:bypass` strategy. Because the main behavor implies that indexes are resetted after migration, so there is no need for extra index updates.
Also indexing might be broken during migrations because of the outdated schema.

Controller actions are wrapped with `:atomic` strategy with middleware just to reduce amount of index update requests inside actions.

It is also a good idea to set up `:bypass` strategy inside your test suite and import objects manually only when needed, plus use `Chewy.massacre` when needed to flush test ES indexes before every example. This will allow to minimize unnecessary ES requests and reduce overhead.


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

Also, queries can be performed on a type individually

```ruby
UsersIndex::User.filter(term: {name: 'foo'}) # will return UserIndex::User collection only
```

If you are performing more than one `filter` or `query` in the chain,
all the filters and queries will be concatenated in the way specified by
`filter_mode` and `query_mode` respectively.

Default `filter_mode` is `:and` and default `query_mode` is `bool`.

Available filter modes are: `:and`, `:or`, `:must`, `:should` and
any minimum_should_match-acceptable value

Available query modes are: `:must`, `:should`, `:dis_max`, any
minimum_should_match-acceptable value or float value for dis_max
query with tie_breaker specified.

```ruby
UsersIndex::User.filter{ name == 'Fred' }.filter{ age < 42 } # will be wrapped with `and` filter
UsersIndex::User.filter{ name == 'Fred' }.filter{ age < 42 }.filter_mode(:should) # will be wrapped with bool `should` filter
UsersIndex::User.filter{ name == 'Fred' }.filter{ age < 42 }.filter_mode('75%') # will be wrapped with bool `should` filter with `minimum_should_match: '75%'`
```

See [query.rb](lib/chewy/query.rb) for more details.

### Additional query action.

You may also perform additional actions on query scope, such as deleting of all the scope documents:

```ruby
UsersIndex.delete_all
UsersIndex::User.delete_all
UsersIndex.filter{ age < 42 }.delete_all
UsersIndex::User.filter{ age < 42 }.delete_all
```

### Filters query DSL.

There is a test version of filters creating DSL:

```ruby
UsersIndex.filter{ name == 'Fred' } # will produce `term` filter.
UsersIndex.filter{ age <= 42 } # will produce `range` filter.
```

The basis of the DSL is expression.
There are 2 types of expressions:

* Simple function

  ```ruby
  UsersIndex.filter{ s('doc["num"] > 1') } # script expression
  UsersIndex.filter{ q(query_string: {query: 'lazy fox'}) } # query expression
  ```

* Field-dependant composite expression.
  Consists of the field name (with dot notation or not),
  value and action operator between them. Field name might take
  additional options for passing to the result expression.

  ```ruby
  UsersIndex.filter{ name == 'Name' } # simple field term filter
  UsersIndex.filter{ name(:bool) == ['Name1', 'Name2'] } # terms query with `execution: :bool` option passed
  UsersIndex.filter{ answers.title =~ /regexp/ } # regexp filter for `answers.title` field
  ```

You can combine expressions as you wish with combination operators help

```ruby
UsersIndex.filter{ (name == 'Name') & (email == 'Email') } # combination produces `and` filter
UsersIndex.filter{
  must(
    should(name =~ 'Fr').should_not(name == 'Fred') & (age == 42), email =~ /gmail\.com/
  ) | ((roles.admin == true) & name?)
} # many of the combination possibilities
```

Also, there is a special syntax for cache enabling:

```ruby
UsersIndex.filter{ ~name == 'Name' } # you can apply tilda to the field name
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

Facets are an optional sidechannel you can request from elasticsearch describing certain fields of the resulting collection. The most common use for facets is to allow the user continue filtering specifically within the subset, as opposed to the global index.

For instance, let's request the ```country``` field as a facet along with our users collection. We can do this with the #facets method like so:

```ruby
UsersIndex.filter{ [...] }.facets({countries: {terms: {field: 'country'}}})
```

Let's look at what we asked from elasticsearch. The facets setter method accepts a hash. You can choose custom/semantic key names for this hash for your own convinience (in this case I used the plural version of the actual field), in our case: ```countries```. The following nested hash tells ES to grab and aggregate values (terms) from the ```country``` field on our indexed records.

When the response comes back, it will have the ```:facets``` sidechannel included:

```
< { ... ,"facets":{"countries":{"_type":"terms","missing":?,"total":?,"other":?,"terms":[{"term":"USA","count":?},{"term":"Brazil","count":?}, ...}}
```

### Script fields

Script fields allow to execute elasticsearch's scripting language such as groovy, javascript and etc. More about supported languages and what is scripting [here](https://www.elastic.co/guide/en/elasticsearch/reference/0.90/modules-scripting.html). This feature allows to calculate distance between geo points, for example. This is how to use the DSL:

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
`coordinates` here is a field with `geo_point` type. There will be `distance` field for the index's model in the search result.

### Script scoring

Script scoring is used to score the search results. All scores are added to the search request and combined according to boost mode and score mode. This can be useful if, for example, a score function is computationally expensive and it is sufficient to compute the score on a filtered set of documents. For example, you might want to multiply the score by another numeric field in the doc:

```ruby
UsersIndex.script_score("_score * doc['my_numeric_field'].value")
```

### Boost Factor

Boost factors are a way to add a boost to a query where documents match the filter. If you have some users who are experts and some are regular users, you might want to give the experts a higher score and boost to the top of the search results. You can accomplish this by using the #boost_factor method and adding a boost score for an expert user of 5:

```ruby
UsersIndex.boost_factor(5, filter: {term: {type: 'Expert'}})
```

### Objects loading

It is possible to load source objects from database for every search result:

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

The `preload` method takes the same options as `load` and ORM/ODM objects will be loaded, but scope will still return array of Chewy wrappers. To access real objects use `_object` wrapper method:

```ruby
UsersIndex.filter(range: {rating: {gte: 100}}).preload(...).query(...).map(&:_object)
```

See [loading.rb](lib/chewy/query/loading.rb) for more details.

### `ActiveSupport::Notifications` support

Chewy has notifing the following events:

#### `search_query.chewy` payload

  * `payload[:index]`: requested index class
  * `payload[:request]`: request hash

#### `import_objects.chewy` payload

  * `payload[:type]`: currently imported type
  * `payload[:import]`: imports stast, total imported and deleted objects count:

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

Inside Rails application some index mantaining rake tasks are defined.

```bash
rake chewy:reset:all # resets all the existing indexes, declared in app/chewy
rake chewy:reset # alias for chewy:reset:all
rake chewy:reset[users] # resets UsersIndex

rake chewy:update:all # updates all the existing indexes, declared in app/chewy
rake chewy:update # alias for chewy:update:all
rake chewy:update[users] # updates UsersIndex
```

### Rspec integration

Just add `require 'chewy/rspec'` to your spec_helper.rb and you will get additional features:
See [update_index.rb](lib/chewy/rspec/update_index.rb) for more details.

If you use `DatabaseCleaner` in your tests with `transaction` (strategy)[https://github.com/DatabaseCleaner/database_cleaner#how-to-use] you may run into the problem that `ActiveRecord`'s models are not indexed automatically on save them despite of the fact that you set the callbacks to do this with the `update_index` method. The issue arises because `chewy` indexes data on `after_commit` run as default but all `after_commit` callbacks are not run with the `DatabaseCleaner`'s' `transaction` strategy. You can solve the issue by changing the `Chewy.use_after_commit_callbacks` option. Just add the following initializer in your Rails application:

```ruby
#config/initializers/chewy.rb
Chewy.use_after_commit_callbacks = !Rails.env.test?
```

## TODO a.k.a coming soon:

* Typecasting support
* Advanced (simplyfied) query DSL: `UsersIndex.query { email == 'my@gmail.com' }` will produce term query
* update_all support
* Maybe, closer ORM/ODM integration, creating index classes implicitly

## Contributing

1. Fork it ( http://github.com/toptal/chewy/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Implement your changes, cover it with specs and make sure old specs are passing
4. Commit your changes (`git commit -am 'Add some feature'`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request

Use the following Rake tasks to control ElasticSearch cluster while developing.

```bash
rake elasticsearch:start # start Elasticsearch cluster on 9250 port for tests
rake elasticsearch:stop # stop Elasticsearch
```

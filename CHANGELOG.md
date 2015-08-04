# master

## Changes

  * Ability to pass a proc to `update_index` to define updating index dynamically (@SeTeM)

# Version 0.8.1

## Bugfixes

  * Added support of elasticsearch-ruby 1.0.10

# Version 0.8.0

## Incompatible changes:

  * `:atomic` and `:urgent` strategies are using `import!` method raising exceptions

## Changes

  * Crutches™ technology

  * Added `.script_fields` chainable method to query (@ka8725)

  * `update_index` matcher mocha support (@lardawge)

  * `:resque` async strategy

  * `:sidekiq` async strategy (inspired by @sharkzp)

  * Added `Query#search_type` for `search_type` request option setup (@marshall-lee)

## Bugfixes

  * Rails 4.2 migrations are not raising UndefinedUpdateStrategy anymore on data updates

  * Mongoid random failing specs fixes (@marshall-lee)

# Version 0.7.0

## Incompatible changes:

  * `Chewy.use_after_commit_callbacks = false` returns previous RDBMS behavior
  in tests

  * ActiveRecord import is now called after_commit instead of after_save and after_destroy

  * Import now respects default scope and removes unmatched documents

  * `delete_from_index?` method is deprecated, use

    ```ruby
      define_type User, delete_if: ->{ removed? } do
        ...
      end
    ```

  * `Chewy.request_strategy` to configure action controller's request wrapping strategy

  * `Chewy.root_strategy` to configure the first strategy in stack

  * Default strategy for controller actions is `:atomic`

  * Default strategy for activerecord migrations is `:bypass`

  * Default strategy for sandbox console is `:bypass`

  * Default strategy for rails console is `:urgent`

  * `Chewy.configuration` was renamed to `Chewy.settings`

  * Reworked index update strategies implementation. `Chewy.atomic`
  and `Chewy.urgent_update` are now deprecated in favour of the new
  `Chewy.strategy` API.

  * Loading objects for object-sourced types using `wrap` method is
  deprecated, `load_one` method should be used instead. Or method name
  might be passed to `define_type`:

    ```ruby
      class GeoData
        def self.get_data(elasticsearch_document)
          REDIS.get("geo_data_#{elasticsearch_document.id}")
        end
      end

      ...
        define_type GeoData, load_one_method: :get_data do
          ...
        end
    ```

## Changes

  * Multiple enhancements by @DNNX

  * Added `script_fields` to search criteria (@ka8725)

  * ORM adapters now completely relies on the default scope. This means every scope or objects passed to import are merged with default scope so basically there is no need to define `delete_if` block. Default scope strongly restricts objects which may land in the current index.

    ```ruby
      define_type Country.where("rating > 30") do

      end

      # this code would import only countries with rating between 30 and 50
      CountriesIndex::Country.import(Country.where("rating < 50"))

      # the same is true for arrays of objects or ids
      CountriesIndex::Country.import(Country.where("rating < 50").to_a)
      CountriesIndex::Country.import(Country.where("rating < 50").pluck(:id))
    ```

  * Object adapter supports custom initial import and load methods, so it
  could be configured to be used with procs or any class responding to `call`
  method.

    ```ruby
      class GeoData
        def self.call
          REDIS.get_all
        end
      end

      ...
        define_type GeoData do
          ...
        end
    ```

  * Nested fields value procs additional arguments: parent objects.

    ```ruby
      define_type Country do
        field :name
        field :cities do
          field :district, value: ->(city, country) { city.districts if country.main? }
        end
      end
    ```

  * Implemented basic named scopes

## Bugfixes

  * `script_score` allow options (@joeljunstrom)

  * Chewy indexes eaged loading fixes (@leemhenson)

  * `Chewy::Index.import nil` imports nothing instead of initial data

# Version 0.6.2

## Changes

  * document root id custom value option (@baronworks)

## Bugfixes

  * Removed decay function defaults (@Linuus)

  * Correct config file handling in case of empty file

# Version 0.6.1

## Changes

  * `min_score` query option support (@jshirley)

  * `Chewy::Query#find` method for finding records by id

# Version 0.6.0

## Changes

  * Mongoid support YaY! (@fabiotomio, @leemhenson)

  * `urgent: true` option for `update_index` is deprecated and will be removed soon, use `Chewy.atomic` instead

  * `timeout` and `timed_out` support (@MarkMurphy)

  * will_paginate support (@josecoelho)

## Bugfixes

  * All the query chainable methods delegated to indexes and types (partially @Linuus)

# Version 0.5.2

## Incompatible changes:

  * `Chewy::Type::Base` removed in favour of using `Chewy::Type` as a base class for all types

## Changes

  * `Chewy.massacre` aliased to `Chewy.delete_all` method deletes all the indexes with current prefix

## Bugfixes:

  * Advanced type classes resolving (@inbeom)

  * `import` ignores nil

# Version 0.5.1

## Changes:

  * `chewy.yml` Rails generator (@jirikolarik)

  * Parent-child mappings feature support (@inbeom)

  * `Chewy::Index.total_count` and `Chewy::Type::Base.total_count`

  * `Chewy::Type::Base.reset` method. Deletes all the type documents and performs import (@jondavidford)

  * Added `Chewy::Query#delete_all` scope method using delete by query ES feature (@jondavidford)

  * Rspec 3 `update_index` matcher support (@jimmybaker)

  * Implemented function scoring (@averell23)

## Bugfixes:

  * Indexed eager-loading fix (@leemhenson)

  * Field type deriving nested type support fix (@rschellhorn)

# Version 0.5.0

## Incompatible changes:

  * 404 exception (IndexMissingException) while query is swallowed and treated like an empty result set.

  * `load` and `preload` for queries became lazy. Might be partially incompatible.

  * Changed mapping behavior: multi-fields are defined in conformity with ElasticSearch documentation (http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/_multi_fields.html#_multi_fields)

## Changes:

  * `suggest` query options support (@rschellhorn).

  * Added hash data support. How it is possible to pass hashes to import.

  * `rake chewy:reset` and `rake chewy:update` paramless acts as `rake chewy:reset:all` and `rake chewy:update:all` respectively

  * Added `delete_from_index?` API method for custom deleted objects marking.

  * Added `post_filter` API, working the same way as filters.

  * Added chainable `strategy` query method.

  * Aliasing is performed in index create request for ElasticSearch >= 1.1.

  * `preload` scope method loads ORM/ODM objects in background.

  * `load` method `:only` and `:except` options to specify load types.

  * `highlight` and `rescore` query options support.

  * config/chewy.yml ERB support.

## Bugfixes:

  * Fixed `missing` and `exists` filters DSL constructors.

  * Reworked index data composing.

  * Support for Kaminari new PaginatableArray behavior (@leemhenson)

  * Correct waiting for status. After index creation, bulk import, and deletion.

  * Fix #23 "wrong constant name" with namespace models

# Version 0.4.0

  * Changed `update_index` matcher behavior. Now it compare array attributes position-independently.

  * Search aggregations API support (@arion).

  * Chewy::Query#facets called without params performs the request and returns facets.

  * Added `Type.template` DSL method for root objects dynamic templates definition. See [mapping.rb](lib/chewy/type/mapping.rb) for more details.

  * ActiveRecord adapter custom `primary_key` support (@matthee).

  * Urgent update now clears association cache in ActiveRecord to ensure latest changes are imported.

  * `import` now creates index before performing.

  * `Chewy.configuration[:wait_for_status]` option. Can be set to `red`, `yellow` or `green`. If set - chewy will wait for cluster status before creating, deleting index and import. Useful for specs.

# Version 0.3.0

  * Added `Chewy.configuration[:index]` config to setup common indexes options.

  * `Chewy.client_options` replaced with `Chewy.configuration`

  * Using source filtering instead of fields filter (http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/search-request-source-filtering.html).

# Version 0.2.3

  * `.import!` indexes method, raises import errors.

  * `.import!` types method, raises import errors. Useful for specs.

# Version 0.2.2

  * Support for `none` scope (@undr).

  * Auto-resolved analyzers and analyzers repository (@webgago):

    ```ruby
      # Setting up analyzers repository:
      Chewy.analyzer :title_analyzer, type: 'custom', filter: %w(lowercase icu_folding title_nysiis)
      Chewy.filter :title_nysiis, type: 'phonetic', encoder: 'nysiis', replace: false

      # Using analyzers from repository in index classes
      class ProductsIndex < Chewy::Index
        settings analysis: {analyzer: ['title_analyzer', {one_more_analyzer: {type: 'custom', tokenizer: 'lowercase'}}]}
      end
    ```

    `title_analyzer` here will be automatically resolved and passed to index mapping

# Version 0.2.0

  * Reworked import error handling. Now all the import errors from ElasticSearch are handled properly, also import method returns true of false depending on the import process success.

  * `Chewy::Index.import` now takes types hash as argument within options hash:

    `PlacesIndex.import city: City.enabled, country: Country.enabled, refresh: false`

  * Old indexes cleanup after reset.

  * Added index prefixes.

  * `define_type` now takes options for adapter.

  * `chewy:reset` and `chewy:reset:all` rake tasks are now trying to reset index with zero downtime if it is possible.

  * Added `chewy:update:all` rake task.

  * Methods `.create`, `.create!`, `.delete`, `.delete`, `reset!` are now supports index name suffix passing as the first argument. See [actions.rb](lib/chewy/index/actions.rb) for more details.

  * Method `reset` renamed to `reset!`.

  * Added common loading scope for AR adapter. Also removed scope proc argument, now it executes just in main load scope context.

    `CitiesIndex.all.load(scope: {city: City.include(:country)})`
    `CitiesIndex.all.load(scope: {city: -> { include(:country) }})`
    `CitiesIndex.all.load(scope: ->{ include(:country) })`

# Version 0.1.0

  * Added filters simplified DSL. See [filters.rb](lib/chewy/query/filters.rb) for more details.

  * Queries and filters join system reworked. See [query.rb](lib/chewy/query.rb) for more details.

  * Added query `merge` method

  * `update_index` matcher now wraps expected block in `Chewy.atomic` by default.
    This behaviour can be prevented with `atomic: false` option passing

    ```ruby
      expect { user.save! }.to update_index('users#user', atomic: false)
    ```

  * Renamed `Chewy.observing_enabled` to `Chewy.urgent_update` with `false` as default

  * `update_elasticsearch` renamed to `update_index`, added `update_index`
    `:urgent` option

  * Added import ActiveSupport::Notifications instrumentation
    `ActiveSupport::Notifications.subscribe('import_objects.chewy') { |*args| }`

  * Added `types!` and `only!` query chain methods, which purges previously
    chained types and fields

  * `types` chain method now uses types filter

  * Added `types` query chain method

  * Changed types access API:

    ```ruby
      UsersIndex::User # => UsersIndex::User
      UsersIndex::types_hash['user'] # => UsersIndex::User
      UsersIndex.user # => UsersIndex::User
      UsersIndex.types # => [UsersIndex::User]
      UsersIndex.type_names # => ['user']
    ```

  * `update_elasticsearch` method name as the second argument

    ```ruby
      update_elasticsearch('users#user', :self)
      update_elasticsearch('users#user', :users)
    ```

  * Changed index handle methods, removed `index_` prefix. I.e. was
    `UsersIndex.index_create`, became `UsersIndex.create`

  * Ability to pass value proc for source object context if arity == 0
    `field :full_name, value: ->{ first_name + last_name }` instead of
    `field :full_name, value: ->(u){ u.first_name + u.last_name }`

  * Added `.only` chain to `update_index` matcher

  * Added ability to pass ActiveRecord::Relation as a scope for load
    `CitiesIndex.all.load(scope: {city: City.include(:country)})`

  * Added method `all` to index for query DSL consistency

  * Implemented isolated adapters to simplify adding new ORMs

  * Query DLS chainable methods delegated to index class
    (no longer need to call MyIndex.search.query, just MyIndex.query)

# Version 0.0.1

  * Query DSL

  * Basic index handling

  * Initial version

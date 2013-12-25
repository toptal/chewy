# master

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

  * Query dsl

  * Basic index hadling

  * Initial version

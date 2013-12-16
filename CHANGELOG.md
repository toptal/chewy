# master

  * Query DLS chainable methods delegated to index class
    (no longer need to call MyIndex.search.query, just MyIndex.query)
  * Implemented isolated adapters to simplify adding new ORMs
  * Added method `all` to index for query DSL consistency
  * Added ability to pass ActiveRecord::Relation as a scope for load
    `CitiesIndex.all.load(scope: {city: City.include(:country)})`
  * Added `.only` chain to `update_index` matcher
  * Ability to pass value proc for source object context if arity == 0
    `field :full_name, value: ->{ first_name + last_name }` instead of
    `field :full_name, value: ->(u){ u.first_name + u.last_name }`

# Version 0.0.1

  * Initial version
  * Basic index hadling
  * Query dsl

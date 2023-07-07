# Changelog

## master (unreleased)

### New Features

### Changes

### Bugs Fixed

## 7.3.3 (2023-07-07)

### New Features

* [#888](https://github.com/toptal/chewy/pull/888/files): Skip journal creation on import ([@konalegi](https://github.com/konalegi))

### Changes

### Bugs Fixed

## 7.3.2 (2023-04-20)

### New Features

### Changes

### Bugs Fixed

* [#861](https://github.com/toptal/chewy/pull/861): Fix bug in mock_elasticsearch_response_sources ([@lafeber](https://github.com/lafeber))

## 7.3.1 (2023-04-20)

### Bugs Fixed

* [#874](https://github.com/toptal/chewy/pull/874): Fix `chewy:journal:clean` task for ruby 3.x. ([@muk-ai](https://github.com/muk-ai))
* [#882](https://github.com/toptal/chewy/pull/882): Fix memory leak during `chewy:reset` for ruby 3.2 ([@konalegi](https://github.com/konalegi))

## 7.3.0 (2023-04-03)

### New Features

* [#869](https://github.com/toptal/chewy/pull/869): New strategy - `delayed_sidekiq`. Allow passing `strategy: :delayed_sidekiq` option to `SomeIndex.import([1, ...], strategy: :delayed_sidekiq)`. The strategy is compatible with `update_fields` option as well. ([@skcc321][])
* [#879](https://github.com/toptal/chewy/pull/879): Configure CI to check for ruby 3.2 compatibility. ([@konalegi][])

### Changes

### Bugs Fixed

* [#856](https://github.com/toptal/chewy/pull/856): Fix return value of subscribed_task_stats used in rake tasks. ([@fabiormoura][])

## 7.2.7 (2022-11-15)

### New Features

* [#857](https://github.com/toptal/chewy/pull/857): Allow passing `wait_for_completion`, `request_per_second` and `scroll_size` options to `chewy:journal:clean` rake task and `delete_all` query builder method. ([@konalegi][])([@barthez][])

### Changes

### Bugs Fixed

* [#863](https://github.com/toptal/chewy/pull/863): Fix `crutches` call doesn't respect `update_fields` option. ([@skcc321][])

## 7.2.6 (2022-06-13)

### New Features

 * [#841](https://github.com/toptal/chewy/pull/841): Add the [`collapse`](https://www.elastic.co/guide/en/elasticsearch/reference/current/collapse-search-results.html) option to the request. ([@jkostolansky][])

### Bugs Fixed

* [#842](https://github.com/toptal/chewy/issues/842): Fix `ignore_blank` handling. ([@rabotyaga][])
* [#848](https://github.com/toptal/chewy/issues/848): Fix invalid journal pagination. ([@konalegi][])

## 7.2.5 (2022-03-04)

### New Features

 * [#827](https://github.com/toptal/chewy/pull/827): Add `:lazy_sidekiq` strategy, that defers not only importing but also `update_index` callback evaluation for created and updated objects. ([@sl4vr][])
 * [#827](https://github.com/toptal/chewy/pull/827): Add `:atomic_no_refresh` strategy. Like `:atomic`, but `refresh=false` parameter is set. ([@barthez][])
 * [#827](https://github.com/toptal/chewy/pull/827): Add `:no_refresh` chain call to `update_index` matcher to ensure import was called with `refresh=false`. ([@barthez][])

### Bugs Fixed

 * [#835](https://github.com/toptal/chewy/pull/835): Support keyword arguments in named scopes. ([@milk1000cc][])

## 7.2.4 (2022-02-03)

### New Features

 * [#760](https://github.com/toptal/chewy/pull/760): Replace parent-child mapping with a [join field](https://www.elastic.co/guide/en/elasticsearch/reference/current/removal-of-types.html#parent-child-mapping-types) ([@mrzasa][])

### Bugs Fixed

 * [#825](https://github.com/toptal/chewy/issues/825): Fix mismatch argument names at update_mapping rake task ([@AgeevAndrew][])
 * [#832](https://github.com/toptal/chewy/issues/832): Fix "cannot load such file -- `i18n/core_ext/hash`" ([@chrisandreae][])

## 7.2.3 (2021-10-29)

### New Features

  * [#801](https://github.com/toptal/chewy/pull/801): Add the [`track_total_hits`](https://www.elastic.co/guide/en/elasticsearch/reference/current/search-your-data.html#track-total-hits) option to the query. ([@milk1000cc][])
  * [#810](https://github.com/toptal/chewy/pull/810): Use `unsafe_load` when loading config to support Psych 4.
  * [#819](https://github.com/toptal/chewy/pull/819): Add the [`ignore_unavailable`](https://www.elastic.co/guide/en/elasticsearch/reference/current/multi-index.html#multi-index) option to the request. ([@kolauren][])

### Changes

  * [#817](https://github.com/toptal/chewy/pull/817): Show warning message during rake chewy:reset or chewy:upgrade if journaling is disabled. ([@konalegi][])

### Bugs Fixed

  * [#816](https://github.com/toptal/chewy/pull/816): Move query [`preference`](https://www.elastic.co/guide/en/elasticsearch/reference/7.x/search-search.html#search-preference) from body to query parameters. ([@afg419][])

## 7.2.2 (2021-05-24)

### Changes

  * [#800](https://github.com/toptal/chewy/pull/800): Revert [#787](https://github.com/toptal/chewy/pull/787) progressbar feature to avoid performance degradation in parallel import ([@rabotyaga][])

  * [#795](https://github.com/toptal/chewy/issues/795): **(Breaking)** Change the Chewy::Search::Parameters::Order implementation to use Array ([@jiajiawang][]):
    * To allow multiple sorting options that may have the same key name. For example script based sorting whose key will always be `_script`.
    * Behaviour change of chained `order` calls.
      * e.g. `.order(_script: {a: 1}).order(_script: {b: 2})`
        * Before `{:sort=>[{"_script"=>{:b=>2}}]}`
        * After  `{:sort=>[{"_script"=>{:a=>1}},{"_script"=>{:b=>2}}]}`

  * [#654](https://github.com/toptal/chewy/issues/654): Add helpers and matchers for testing ([@Vitalina-Vakulchyk][]):
    * `mock_elasticsearch_response` helpers both Rspec and Minitest - to mock elasticsearch response
    * `mock_elasticsearch_response_sources` helpers both Rspec and Minitest - to mock elasticsearch response sources
    * `assert_elasticsearch_query` helper for Minitest - to compare request and expected query (returns `true`/`false`)
    * `build_query` matcher for Rspec - to compare request and expected query (returns `true`/`false`)

## 7.2.1 (2021-05-11)

### New Features

  * [#469](https://github.com/toptal/chewy/issues/469): Add ability to output the progressbar with `ENV['PROGRESS']` during `reset` rake tasks ([@Vitalina-Vakulchyk][]):
    * for `rake chewy:reset` and `rake chewy:parallel:reset`
    * progressbar is hidden by default, set `ENV['PROGRESS']` to `true` to display it

### Bugs Fixed

  * [#796](https://github.com/toptal/chewy/pull/796): Fix clear scroll: pass `scroll_id` in body, as passing in path parameters is deprecated and can overflow `http.max_initial_line_length` ([@rabotyaga][])

## 7.0.1 (2021-05-03)

### Changes

  * [#792](https://github.com/toptal/chewy/pull/792): Skip ES version memoization for search requests ([@rabotyaga][])
    * See the Migration Guide for details

## 7.2.0 (2021-04-19)

### New Features

  * [#778](https://github.com/toptal/chewy/pull/778): Add `ignore_blank` option to `field` method ([@Vitalina-Vakulchyk][]):
    * `true` by default for the `geo_point` type
    * `false` by default for other types

### Changes

  * [#783](https://github.com/toptal/chewy/pull/783): **(Breaking)** Remove `Chewy::Type`, simplify DSL ([@rabotyaga][])
    * Remove the `Chewy::Type` class
        * e.g. remove `CitiesIndex::City` / `CitiesIndex.city`
            * `CitiesIndex::City.import! ...` becomes `CitiesIndex.import! ...`
    * Simplify index DSL:
        * `define_type` block -> `index_scope` clause
            * it can be omitted completely, if you don't need to specify the scope or options, e.g. `name`
    * Remove type names from string representations:
        * in `update_index` ActiveRecord helper and RSpec matcher, e.g.
            * `update_index('cities#city')` -> `update_index('cities')`
            * `update_index(UsersIndex::User)` -> `update_index(UsersIndex)`
        * in rake tasks (e.g. `rake chewy:update[cities#city]` -> `rake chewy:update[cities]`)
        * in rake tasks output (e.g. `Imported CitiesIndex::City in 1s, stats: index 3` -> `Imported CitiesIndex in 1s, stats: index 3`)
    * Use index name instead of type name in loader additional scope
        * e.g. `CitiesIndex.filter(...).load(city: {scope: City.where(...)})` -> `CitiesIndex.filter(...).load(cities: {scope: City.where(...)})`
  * [#692](https://github.com/toptal/chewy/issues/692): Add `.update_mapping` to Index class ([@Vitalina-Vakulchyk][]):
    * Wrapped Elasticsearch gem `.put_mapping` with `.update_mapping` in Index class
    * Add `rake chewy:update_mapping` task
  * [#594](https://github.com/toptal/chewy/issues/594): Add `.reindex` to Index class ([@Vitalina-Vakulchyk][]):
    * Wrapped Elasticsearch gem `.reindex` with `.reindex` in Index class
    * Add `rake chewy:reindex` task
  * [#679](https://github.com/toptal/chewy/issues/679): Wrapped `Elasticsearch::API::Indices::Actions#clear_cache` with `.clear_cache` in Index class ([@Vitalina-Vakulchyk][])
  * [#495](https://github.com/toptal/chewy/issues/495): Ability to change Rails console strategy with `Chewy.console_strategy` ([@Vitalina-Vakulchyk][])
  * [#778](https://github.com/toptal/chewy/pull/778): **(Breaking)** Drop support for Ruby 2.5 ([@Vitalina-Vakulchyk][])
  * [#776](https://github.com/toptal/chewy/pull/776): **(Breaking)** Removal of unnecessary features and integrations ([@Vitalina-Vakulchyk][]):
    * `aws-sdk-sqs` / `shoryuken`
    * `mongoid`
    * `sequel`
    * `will_paginate`
    * `resque`
  * [#769](https://github.com/toptal/chewy/pull/769): **(Breaking)** Removal of deprecated methods and rake tasks ([@Vitalina-Vakulchyk][]):
    * `Chewy::Index.index_params` is removed, use `Chewy::Index.specification_hash` instead
    * `Chewy::Index.derivable_index_name` is removed, use `Chewy::Index.derivable_name` instead
    * `Chewy::Index.default_prefix` is removed, use `Chewy::Index.prefix` instead
    * `Chewy::Index.build_index_name` is removed, use `Chewy::Index.index_name` instead
    * `Chewy::RakeHelper.reset_index` is removed, use `Chewy::RakeHelper.reset` instead
    * `Chewy::RakeHelper.reset_all` is removed, use `Chewy::RakeHelper.reset` instead
    * `Chewy::RakeHelper.update_index` is removed, use `Chewy::RakeHelper.update` instead
    * `Chewy::RakeHelper.update_all` is removed, use `Chewy::RakeHelper.update` instead
    * `rake chewy:apply_changes_from` is removed, use `rake chewy:journal:apply` instead
    * `rake chewy:clean_journal` is removed, use `rake chewy:journal:clean` instead

## 7.1.0 (2021-03-03)

### Changes

  * [#766](https://github.com/toptal/chewy/pull/766): **(Breaking)** Drop support for Elasticsearch 6.x ([@rabotyaga][])
  * [#765](https://github.com/toptal/chewy/pull/765): Fix ruby 2.7 warnings in rake tasks ([@aglushkov][])

### Bugs Fixed

  * [#722](https://github.com/toptal/chewy/issues/722): Remove alias_method_chain, use Module#prepend instead ([@dalthon][])

## 7.0.0 (2021-02-22)

### New Features

  * [#763](https://github.com/toptal/chewy/pull/763): Added support for Elasticsearch 7 ([@rabotyaga][])

### Changes

  * [#757](https://github.com/toptal/chewy/pull/757): **(Breaking)** Fix `Chewy::Index.index` & `Chewy::Index.aliases` to correctly report indexes and aliases ([@mpeychich][], [@dalthon][])
  * [#761](https://github.com/toptal/chewy/pull/761): Avoid fetching scope data to check if it is blank ([@dalthon][])

## 6.0.0 (2021-02-11)

### Changes

  * [#743](https://github.com/toptal/chewy/pull/743): **(Breaking)** Elasticsearch 6.x support added. See the [migration guide](migration_guide.md) & ES [breaking changes](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/breaking-changes-6.0.html). Removed legacy DSL support. Removed support for ES < 5. ([@mrzasa][], [@konalegi][], [@rabotyaga][])
  * [#751](https://github.com/toptal/chewy/pull/751): Add [Multi Search API](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/search-multi-search.html) support. ([@mpeychich][], [@dalthon][])
  * [#755](https://github.com/toptal/chewy/pull/755): `attribute_highlights` returns an array of highlights. ([@musaffa][], [@dalthon][])
  * [#753](https://github.com/toptal/chewy/pull/753): Add support for direct_import parameter to skip objects reloading. ([@TikiTDO][], [@dalthon][])
  * [#739](https://github.com/toptal/chewy/pull/739): Remove explicit `main` branch dependencies on `rspec-*` gems after `rspec-mocks` 3.10.2 is released. ([@rabotyaga][])

### Bugs Fixed

* [#695](https://github.com/toptal/chewy/pull/695): Clear the scroll by id after completing `scroll_batches`. ([@socialchorus][])
* [#749](https://github.com/toptal/chewy/pull/749): Avoid importing everything when given an empty relation. ([@JF-Lalonde][], [@dalthon][])
* [#736](https://github.com/toptal/chewy/pull/736): Fix nil children when using witchcraft. ([@taylor-au][])

## 5.2.0 (2021-01-28)

### Changes

  * [#734](https://github.com/toptal/chewy/pull/734): Add support for Ruby 3. ([@lowang][])
  * [#735](https://github.com/toptal/chewy/pull/735): Correct deprecation warning for Elasticsearch 5.6 to 6: empty query for`_delete_by_query`, delete by alias, `index_already_exists_exception` renaming. ([@bhacaz][])
  * [#733](https://github.com/toptal/chewy/pull/733): Update gemspec dependencies for Rails. Update CI gemfiles and matrix to tests against current LTS Rails versions. ([@bhacaz][])
  * Tweak some wording and formatting; add a note about compatibility; update copyright; remove broken logo; update the CI badge. ([@bbatsov][])
  * [#714](https://github.com/toptal/chewy/pull/714): Update instructions for AWS ElasticSearch. ([@olancheg][])
  * [#728](https://github.com/toptal/chewy/pull/728): Fix more ruby 2.7 keyword params deprecation warnings. ([@aglushkov][])
  * [#715](https://github.com/toptal/chewy/pull/715): Fixed all deprecation warnings in Ruby 2.7. ([@gseddon][])
  * [#718](https://github.com/toptal/chewy/pull/718): Added Ruby 2.7 to CircleCI config. ([@mrzasa][])
  * [#707](https://github.com/toptal/chewy/pull/707): Allow configuration of Active Job queue name. ([@mrzasa][])
  * [#711](https://github.com/toptal/chewy/pull/711): Setup CI on CircleCI. ([@mrzasa][])
  * [#710](https://github.com/toptal/chewy/pull/710): Fix deprecation warning for constructing new `BigDecimal`. ([@AlexVPopov][])

## 5.1.0 (2019-09-24)

### Changes

  * [#657](https://github.com/toptal/chewy/pull/657): **(Breaking)** Add support for multiple indices in request. ([@pyromaniac][])
  * [#647](https://github.com/toptal/chewy/pull/647): **(Breaking)** Support `search_type`, `request_cache`, and `allow_partial_search_results` as query string parameters. ([@mattzollinhofer][])
  * [#606](https://github.com/toptal/chewy/pull/606): Speed up imports when `bulk_size` is specified. ([@yahooguntu][])
  * [#682](https://github.com/toptal/chewy/pull/682): Insert `RequestStrategy` middleware before `ActionDispatch::ShowExceptions`. ([@dck][])

## 5.0.0 (2018-02-13)

### Changes

  * **(Breaking)** Align the gem version with the most recent ElasticSearch version we support.
  * **(Breaking)** `Chewy.default_field_type` is `text` now.
  * **(Breaking)** `Chewy::Stash` was split onto two indexes - `Chewy::Stash::Specification` and `Chewy::Stash::Journal`.
  * **(Breaking)** Data for journal and specification is stored in binary fields base64-encoded to bypass the limits of other fields.
  * **(Breaking)** [#626](https://github.com/toptal/chewy/pull/626): Don't underscore suggested index name. ([@dm1try][])
  * [#598](https://github.com/toptal/chewy/pull/598): `pipeline` import option support. ([@eManPrague][])
  * [#625](https://github.com/toptal/chewy/pull/625): Proper Rails check. ([@nattfodd][])
  * [#623](https://github.com/toptal/chewy/pull/623): Bypass strategy performance improvements. ([@DNNX][])
  * [#620](https://github.com/toptal/chewy/pull/620): Avoid index update calls for empty data. ([@robertasg][])
  * Do not underscore suggested index name on `Chewy::Index.index_name` call.
  * It is possible now to call `root` method several times inside a single type definition, the options will be merged. Also, the block isn't required anymore.
  * [#565](https://github.com/toptal/chewy/pull/565): Fixed some Sequel deprecation warnings. ([@arturtr][])
  * [#577](https://github.com/toptal/chewy/pull/577): Fixed some Sequel deprecation warnings. ([@matchbookmac][])

### Bugs Fixed

  * [#593](https://github.com/toptal/chewy/pull/593): Fixed index settings logic error. ([@yahooguntu][])
  * [#567](https://github.com/toptal/chewy/pull/567): Missed check in higlight method. ([@heartfulbird][])

-----------------------------------------------------------------------------------

## 0.10.1

### Changes

  * [#558](https://github.com/toptal/chewy/pull/558): Improved parallel worker titles

### Bugs Fixed

  * [#557](https://github.com/toptal/chewy/pull/557): Fixed request strategy initial debug message
  * [#556](https://github.com/toptal/chewy/pull/556): Fixed will objects paginated array initialization when pagination was not used
  * [#555](https://github.com/toptal/chewy/pull/555): Fixed fields symbol/string value
  * [#554](https://github.com/toptal/chewy/pull/554): Fixed root field value proc

## 0.10.0

### Breaking changes

  * Changed behavior of `Chewy::Index.index_name`, it doesn't cache the values anymore.
  * Journal interfaces, related code and rake tasks were completely refactored and are not compatible with the previous version.

### Changes

  * [#543](https://github.com/toptal/chewy/pull/543): Less noisy strategies logging ([@Borzik][])
  * Parallel import and the corresponding rake tasks.
  * [#532](https://github.com/toptal/chewy/pull/532): `:shoryuken` async strategy ([@josephchoe][])
  * Deprecate `Chewy::Index.build_index_name`.
  * Rename `Chewy::Index.default_prefix` to `Chewy::Index.prefix`. The old one is deprecated.
  * Add `Chewy::Type.derivable_name` for consistency.
  * Rename `Chewy::Index.derivable_index_name` to `Chewy::Index.derivable_name`.
    `Chewy::Index.derivable_index_name` and `Chewy::Type.derivable_index_name` are deprecated.
  * Use normal YAML loading, for the config, we don't need the safe one.
  * [#526](https://github.com/toptal/chewy/pull/526): `default_root_options` option ([@barthez][])
  * Partial indexing ability: it is possible to update only specified fields.
  * New cool `rake chewy:deploy` task.
  * Selective reset (resets only if necessary): `rake chewy:upgrade`.
  * Consistency checks and synchronization: `rake chewy:sync`.
  * Brand new request DSL. Supports ElasticSearch 2 and 5, better usability, architecture and docs.
  * Add Kaminari 1.0 support.
  * [#483](https://github.com/toptal/chewy/pull/483): `skip_index_creation_on_import` option ([@sergey-kintsel][])
  * [#481](https://github.com/toptal/chewy/pull/481): Ability to use procs for settings ([@parallel588][])
  * [#467](https://github.com/toptal/chewy/pull/467): Bulk indexing optimizations with new additional options ([@eproulx-petalmd][])
  * [#438](https://github.com/toptal/chewy/pull/438): Configurable sidekiq options ([@averell23][])

## 0.9.0

### Changes

  * [#443](https://github.com/toptal/chewy/pull/443): Add `preference` param to Query ([@menglewis][])
  * [#417](https://github.com/toptal/chewy/pull/417): Add the `track_scores` option to the query; `_score` to be computed and tracked even when there are no `_score` in sort. ([@dmitry][])
  * [#414](https://github.com/toptal/chewy/pull/414), [#433](https://github.com/toptal/chewy/pull/433), [#439](https://github.com/toptal/chewy/pull/439): Confugurable `Chewy.indices_path` ([@robacarp][])
  * [#409](https://github.com/toptal/chewy/pull/409), [#425](https://github.com/toptal/chewy/pull/425), [#428](https://github.com/toptal/chewy/pull/428), [#432](https://github.com/toptal/chewy/pull/432), [#434](https://github.com/toptal/chewy/pull/434), [#463](https://github.com/toptal/chewy/pull/463): [Journaling](https://github.com/toptal/chewy/#journaling) implementation ([@sergey-kintsel][])
  * [#396](https://github.com/toptal/chewy/pull/396): Minitest helpers ([@robacarp][])
  * [#393](https://github.com/toptal/chewy/pull/393): `Chewy::Query#unlimited` to fetch all the documents ([@sergey-kintsel][])
  * [#386](https://github.com/toptal/chewy/pull/386): `Chewy::Query#exists?` ([@sergey-kintsel][])
  * [#381](https://github.com/toptal/chewy/pull/381), [#376](https://github.com/toptal/chewy/pull/376): Import otimizations
  * [#375](https://github.com/toptal/chewy/pull/375): Additional import optimization technique - [raw import](https://github.com/toptal/chewy/#raw-import) ([@DNNX][])
  * [#380](https://github.com/toptal/chewy/pull/380): `weight` scoring dunction was added to the search DSL ([@sevab][])
  * Rake tasks support multiple indexes and exceptions: `rake chewy:reset[users,projects]`, `rake chewy:update[-projects]`
  * Witchcraft™ supports dynamically generated procs with variables from closure.
  * Added `Query#preference` for specifying shard replicas to query against. ([@menglewis][])

### Bugs Fixed

  * [#415](https://github.com/toptal/chewy/pull/415): `.script_fields` method in the Index class ([@dmitry][])
  * [#398](https://github.com/toptal/chewy/pull/398): Fix routing_missing_exception on delete with parent missing ([@guigs][])
  * [#385](https://github.com/toptal/chewy/pull/385): Sequel custom primary keys handling fix ([@okliv][])
  * [#374](https://github.com/toptal/chewy/pull/374): Bulk import fixes ([@0x0badc0de][])

## 0.8.4

### Changes

  * Brand new import `:bulk_size` option, set desired ElasticSearch bulk size in bytes
  * Witchcraft™ technology
  * [#341](https://github.com/toptal/chewy/pull/341): Configurable per-type default import options ([@barthez][])
  * Various codebase optimizations ([@DNNX][], [@pyromaniac][])
  * `update_index` Rspec matcher messages improvements
  * `:all` rake tasks deprecation
  * [#335](https://github.com/toptal/chewy/pull/335): Scoped notification subscriptions in rake tasks ([@0x0badc0de][])
  * [#321](https://github.com/toptal/chewy/pull/321): Async strategies workers accept options ([@dnd][])
  * [#314](https://github.com/toptal/chewy/pull/314): Prefix is configurable per-index ([@mikeyhogarth][])
  * [#302](https://github.com/toptal/chewy/pull/302), [#339](https://github.com/toptal/chewy/pull/339): Ability to pass proc for transport configuration ([@feymartynov][], [@reidab][])
  * [#297](https://github.com/toptal/chewy/pull/297): ElasticSearch 2 support ([@sergeygaychuk][])
  * Accessing types with methods is deprecated. Use `MyIndex::MyType` constant reference instead of `MyIndex.my_type` method.
  * [#294](https://github.com/toptal/chewy/pull/294): Sequel adapter improvements ([@mrbrdo][])

### Bugs Fixed

  * [#325](https://github.com/toptal/chewy/pull/325): Mongoid atomic strategy fix
  * [#324](https://github.com/toptal/chewy/pull/324): Method missing fix ([@jesjos][])
  * [#319](https://github.com/toptal/chewy/pull/319): Hash fields composition fix ([@eproulx-petalmd][])
  * [#306](https://github.com/toptal/chewy/pull/306): Better errors handling in strategies ([@barthez][])
  * [#303](https://github.com/toptal/chewy/pull/303): Assets strategies silencer fix for Rails 5 API mode ([@clupprich][])

## 0.8.3

### Breaking changes:

  * `Chewy.atomic` and `Chewy.urgent_update=` methods was removed from the codebase, use `Chewy.strategy` block instead.
  * `delete_from_index?` hook is removed from the codebase.

### Changes

  * Sequel support completely reworked to use common ORM implementations + better sequel specs covarage.

### Bugs Fixed

  * Sequel objects transactional destruction fix
  * Correct Rspec mocking framework checking ([@mainameiz][])
  * Atomic strategy is now compatible with custom ids proc.
  * Safe unsubscribe on import ([@marshall-lee][])
  * Correct custom assets path silencer ([@davekaro][])

## 0.8.2

### Changes

  * ActiveJob strategy by [@mkcode][]
  * Async strategies tweak ([@AndreySavelyev][])
  * GeoPoint readme ([@joonty][])
  * Multiple grammar fixes and code improvements ([@biow0lf][])
  * Named aggregations by [@caldwecr][]
  * Sequel adapter by [@jirutka][]
  * Rake helper methods extracted ([@caldwecr][], [@jirutka][])
  * Multiple grammar fixes ([@henrebotha][])
  * Ability to pass a proc to `update_index` to define updating index dynamically ([@SeTeM][])

### Bugs Fixed

  * Fixed transport logger and tracer configuration

## 0.8.1

### Bugs Fixed

  * Added support of elasticsearch-ruby 1.0.10

## 0.8.0

### Breaking changes:

  * `:atomic` and `:urgent` strategies are using `import!` method raising exceptions

### Changes

  * Crutches™ technology
  * Added `.script_fields` chainable method to query ([@ka8725][])
  * `update_index` matcher mocha support ([@lardawge][])
  * `:resque` async strategy
  * `:sidekiq` async strategy (inspired by [@sharkzp][])
  * Added `Query#search_type` for `search_type` request option setup ([@marshall-lee][])

### Bugs Fixed

  * Rails 4.2 migrations are not raising UndefinedUpdateStrategy anymore on data updates
  * Mongoid random failing specs fixes ([@marshall-lee][])

## 0.7.0

### Breaking changes:

  * `Chewy.use_after_commit_callbacks = false` returns previous RDBMS behavior in tests
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
  * Reworked index update strategies implementation. `Chewy.atomic` and `Chewy.urgent_update` are now deprecated in favour of the new `Chewy.strategy` API.
  * Loading objects for object-sourced types using `wrap` method is deprecated, `load_one` method should be used instead. Or method name might be passed to `define_type`:
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

### Changes

  * Multiple enhancements by [@DNNX][]
  * Added `script_fields` to search criteria ([@ka8725][])
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
  * Object adapter supports custom initial import and load methods, so it could be configured to be used with procs or any class responding to `call` method.
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

### Bugs Fixed

  * `script_score` allow options ([@joeljunstrom][])
  * Chewy indexes eaged loading fixes ([@leemhenson][])
  * `Chewy::Index.import nil` imports nothing instead of initial data

## 0.6.2

### Changes

  * document root id custom value option ([@baronworks][])

### Bugs Fixed

  * Removed decay function defaults ([@Linuus][])
  * Correct config file handling in case of empty file

## 0.6.1

### Changes

  * `min_score` query option support ([@jshirley][])
  * `Chewy::Query#find` method for finding documents by id

## 0.6.0

### Changes

  * Mongoid support YaY! ([@fabiotomio][], [@leemhenson][])
  * `urgent: true` option for `update_index` is deprecated and will be removed soon, use `Chewy.atomic` instead
  * `timeout` and `timed_out` support ([@MarkMurphy][])
  * will_paginate support ([@josecoelho][])

### Bugs Fixed

  * All the query chainable methods delegated to indexes and types (partially [@Linuus][])

## 0.5.2

### Breaking changes:

  * `Chewy::Type::Base` removed in favour of using `Chewy::Type` as a base class for all types

### Changes

  * `Chewy.massacre` aliased to `Chewy.delete_all` method deletes all the indexes with current prefix

### Bugs Fixed:

  * Advanced type classes resolving ([@inbeom][])
  * `import` ignores nil

## 0.5.1

### Changes:

  * `chewy.yml` Rails generator ([@jirikolarik][])
  * Parent-child mappings feature support ([@inbeom][])
  * `Chewy::Index.total_count` and `Chewy::Type::Base.total_count`
  * `Chewy::Type::Base.reset` method. Deletes all the type documents and performs import ([@jondavidford][])
  * Added `Chewy::Query#delete_all` scope method using delete by query ES feature ([@jondavidford][])
  * Rspec 3 `update_index` matcher support ([@jimmybaker][])
  * Implemented function scoring ([@averell23][])

### Bugs Fixed:

  * Indexed eager-loading fix ([@leemhenson][])
  * Field type deriving nested type support fix ([@rschellhorn][])

## 0.5.0

### Breaking changes:

  * 404 exception (IndexMissingException) while query is swallowed and treated like an empty result set.
  * `load` and `preload` for queries became lazy. Might be partially incompatible.
  * Changed mapping behavior: multi-fields are defined in conformity with ElasticSearch documentation (http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/_multi_fields.html#_multi_fields)

### Changes:

  * `suggest` query options support ([@rschellhorn][]).
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

### Bugs Fixed:

  * Fixed `missing` and `exists` filters DSL constructors.
  * Reworked index data composing.
  * Support for Kaminari new PaginatableArray behavior ([@leemhenson][])
  * Correct waiting for status. After index creation, bulk import, and deletion.
  * [#23](https://github.com/toptal/chewy/pull/23): Fix "wrong constant name" with namespace models

## 0.4.0

  * Changed `update_index` matcher behavior. Now it compare array attributes position-independently.
  * Search aggregations API support ([@arion][]).
  * Chewy::Query#facets called without params performs the request and returns facets.
  * Added `Type.template` DSL method for root objects dynamic templates definition. See [mapping.rb](lib/chewy/type/mapping.rb) for more details.
  * ActiveRecord adapter custom `primary_key` support ([@matthee][]).
  * Urgent update now clears association cache in ActiveRecord to ensure latest changes are imported.
  * `import` now creates index before performing.
  * `Chewy.configuration[:wait_for_status]` option. Can be set to `red`, `yellow` or `green`. If set - chewy will wait for cluster status before creating, deleting index and import. Useful for specs.

## 0.3.0

  * Added `Chewy.configuration[:index]` config to setup common indexes options.
  * `Chewy.client_options` replaced with `Chewy.configuration`
  * Using source filtering instead of fields filter (http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/search-request-source-filtering.html).

## 0.2.3

  * `.import!` indexes method, raises import errors.
  * `.import!` types method, raises import errors. Useful for specs.

## 0.2.2

  * Support for `none` scope ([@undr][]).
  * Auto-resolved analyzers and analyzers repository ([@webgago][]):
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

## 0.2.0

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

## 0.1.0

  * Added filters simplified DSL. See [filters.rb](lib/chewy/query/filters.rb) for more details.
  * Queries and filters join system reworked. See [query.rb](lib/chewy/query.rb) for more details.
  * Added query `merge` method
  * `update_index` matcher now wraps expected block in `Chewy.atomic` by default. This behaviour can be prevented with `atomic: false` option passing
    ```ruby
      expect { user.save! }.to update_index('users#user', atomic: false)
    ```
  * Renamed `Chewy.observing_enabled` to `Chewy.urgent_update` with `false` as default
  * `update_elasticsearch` renamed to `update_index`, added `update_index` `:urgent` option
  * Added import ActiveSupport::Notifications instrumentation `ActiveSupport::Notifications.subscribe('import_objects.chewy') { |*args| }`
  * Added `types!` and `only!` query chain methods, which purges previously chained types and fields
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
  * Changed index handle methods, removed `index_` prefix. I.e. was `UsersIndex.index_create`, became `UsersIndex.create`
  * Ability to pass value proc for source object context if arity == 0 `field :full_name, value: ->{ first_name + last_name }` instead of `field :full_name, value: ->(u){ u.first_name + u.last_name }`
  * Added `.only` chain to `update_index` matcher
  * Added ability to pass ActiveRecord::Relation as a scope for load `CitiesIndex.all.load(scope: {city: City.include(:country)})`
  * Added method `all` to index for query DSL consistency
  * Implemented isolated adapters to simplify adding new ORMs
  * Query DLS chainable methods delegated to index class (no longer need to call MyIndex.search.query, just MyIndex.query)

## 0.0.1

  * Query DSL
  * Basic index handling
  * Initial version

[@0x0badc0de]: https://github.com/0x0badc0de
[@AgeevAndrew]: https://github.com/AgeevAndrew
[@aglushkov]: https://github.com/aglushkov
[@AlexVPopov]: https://github.com/AlexVPopov
[@AndreySavelyev]: https://github.com/AndreySavelyev
[@afg419]: https://github.com/afg419
[@arion]: https://github.com/arion
[@arturtr]: https://github.com/arturtr
[@averell23]: https://github.com/averell23
[@baronworks]: https://github.com/baronworks
[@barthez]: https://github.com/barthez
[@bbatsov]: https://github.com/bbatsov
[@bhacaz]: https://github.com/bhacaz
[@biow0lf]: https://github.com/biow0lf
[@Borzik]: https://github.com/Borzik
[@caldwecr]: https://github.com/caldwecr
[@chrisandreae]: https://github.com/chrisandreae
[@clupprich]: https://github.com/clupprich
[@dalthon]: https://github.com/dalthon
[@davekaro]: https://github.com/davekaro
[@dck]: https://github.com/dck
[@dm1try]: https://github.com/dm1try
[@dmitry]: https://github.com/dmitry
[@dnd]: https://github.com/dnd
[@DNNX]: https://github.com/DNNX
[@eManPrague]: https://github.com/eManPrague
[@eproulx-petalmd]: https://github.com/eproulx-petalmd
[@fabiotomio]: https://github.com/fabiotomio
[@feymartynov]: https://github.com/feymartynov
[@gseddon]: https://github.com/gseddon
[@guigs]: https://github.com/guigs
[@heartfulbird]: https://github.com/heartfulbird
[@henrebotha]: https://github.com/henrebotha
[@inbeom]: https://github.com/inbeom
[@jesjos]: https://github.com/jesjos
[@JF-Lalonde]: https://github.com/JF-Lalonde
[@jiajiawang]: https://github.com/jiajiawang
[@jimmybaker]: https://github.com/jimmybaker
[@jirikolarik]: https://github.com/jirikolarik
[@jirutka]: https://github.com/jirutka
[@jkostolansky]: https://github.com/jkostolansky
[@joeljunstrom]: https://github.com/joeljunstrom
[@jondavidford]: https://github.com/jondavidford
[@joonty]: https://github.com/joonty
[@josecoelho]: https://github.com/josecoelho
[@josephchoe]: https://github.com/josephchoe
[@jshirley]: https://github.com/jshirley
[@ka8725]: https://github.com/ka8725
[@kolauren]: https://github.com/kolauren
[@konalegi]: https://github.com/konalegi
[@lardawge]: https://github.com/lardawge
[@leemhenson]: https://github.com/leemhenson
[@Linuus]: https://github.com/Linuus
[@lowang]: https://github.com/lowang
[@mainameiz]: https://github.com/mainameiz
[@MarkMurphy]: https://github.com/MarkMurphy
[@marshall]: https://github.com/marshall
[@matchbookmac]: https://github.com/matchbookmac
[@matthee]: https://github.com/matthee
[@mattzollinhofer]: https://github.com/mattzollinhofer
[@menglewis]: https://github.com/menglewis
[@mikeyhogarth]: https://github.com/mikeyhogarth
[@milk1000cc]: https://github.com/milk1000cc
[@mkcode]: https://github.com/mkcode
[@mpeychich]: https://github.com/mpeychich
[@mrbrdo]: https://github.com/mrbrdo
[@mrzasa]: https://github.com/mrzasa
[@musaffa]: https://github.com/musaffa
[@nattfodd]: https://github.com/nattfodd
[@okliv]: https://github.com/okliv
[@olancheg]: https://github.com/olancheg
[@parallel588]: https://github.com/parallel588
[@pyromaniac]: https://github.com/pyromaniac
[@rabotyaga]: https://github.com/rabotyaga
[@reidab]: https://github.com/reidab
[@robacarp]: https://github.com/robacarp
[@robertasg]: https://github.com/robertasg
[@rschellhorn]: https://github.com/rschellhorn
[@sergey-kintsel]: https://github.com/sergey-kintsel
[@sergeygaychuk]: https://github.com/sergeygaychuk
[@SeTeM]: https://github.com/SeTeM
[@sevab]: https://github.com/sevab
[@sharkzp]: https://github.com/sharkzp
[@socialchorus]: https://github.com/socialchorus
[@taylor-au]: https://github.com/taylor-au
[@TikiTDO]: https://github.com/TikiTDO
[@undr]: https://github.com/undr
[@Vitalina-Vakulchyk]: https://github.com/Vitalina-Vakulchyk
[@webgago]: https://github.com/webgago
[@yahooguntu]: https://github.com/yahooguntu

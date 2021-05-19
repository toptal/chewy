# Migration guide

This document outlines the steps you need to take when migrating between major versions of
Chewy and Elasticsearch. For simplicity's sake the guide will assume that you're using
Chewy alongside a matching Elasticsearch version.

## Chewy 6/Elasticsearch 6 to Chewy 7/Elasticsearch 7

In order to upgrade Chewy 6/Elasticsearch 6 to Chewy 7/Elasticsearch 7 in the most seamless manner you have to:

* Upgrade to the latest 6.x stable releases, namely Chewy 6.0, Elasticsearch 6.8
* Study carefully [Breaking changes in 7.0](https://www.elastic.co/guide/en/elasticsearch/reference/current/breaking-changes-7.0.html), make sure your application conforms.
* Run your test suite on Chewy 7.0 / Elasticsearch 7
* Run manual tests on Chewy 7.0 / Elasticsearch 7
* Upgrade to Chewy 7.0
  * The “total hits” counter is an integer for ES versions < 7 and an object (hash) for the versions starting from 7.0.0. Elasticsearch added a special option, `rest_total_hits_as_int`, to ease the upgrade, that could be appended to any request and results in the old “total hits” format. Unfortunately, this option is not recognized by ES versions prior to 7.0.0, which means that we have to check the version to decide if we need this option.
    Normally Chewy does memoization of the current ES version, but this might be inappropriate for the upgrade, as the version changes live.
    To handle that we have 2 versions of Chewy for this stage of the upgrade: 7.0.0 and 7.0.1. Version 7.0.0 does the memoization and version 7.0.1 requests the current version on every search request. 
  * You can use the 7.0.0 version if it's fine for you to have an application restart immediately after ES cluster upgrade.
  * If you're using the 7.0.1 version you might be interested in keeping the timeframe between this step and updating to Chewy 7.1 as small as possible, as version 7.0.1 skips ES version memoization for search requests to help dynamically detect ES version. This leads to an extra version request on each search request, i.e. could affect the overall performance/latency of the search and a load of ES cluster.
* Perform a [rolling upgrade](https://www.elastic.co/guide/en/elasticsearch/reference//rolling-upgrades.html) of Elasticsearch
* Run your test suite on Chewy 7.1 / Elasticsearch 7
* Run manual tests on Chewy 7.1 / Elasticsearch 7
* Upgrade to Chewy 7.1
* Upgrade to Chewy 7.2:
  * Remove all the the `Chewy::Type` class usages, e.g. remove `CitiesIndex::City` / `CitiesIndex.city`
    * `CitiesIndex::City.import! ...` becomes `CitiesIndex.import! ...`
  * Update indexes with simplified DSL:
    * `define_type` block -> `index_scope` clause
      * it can be omitted completely, if you don't need to specify the scope or options, e.g. `name`
  * Remove type names from string representations:
    * in `update_index` ActiveRecord helper and RSpec matcher, e.g.
      * `update_index('cities#city')` -> `update_index('cities')`
      * `update_index(UsersIndex::User)` -> `update_index(UsersIndex)`
    * in rake tasks (e.g. `rake chewy:update[cities#city]` -> `rake chewy:update[cities]`)
    * rake tasks output is also changed (e.g. `Imported CitiesIndex::City in 1s, stats: index 3` -> `Imported CitiesIndex in 1s, stats: index 3`)
  * Use index name instead of type name in loader additional scope
    * e.g. `CitiesIndex.filter(...).load(city: {scope: City.where(...)})` -> `CitiesIndex.filter(...).load(cities: {scope: City.where(...)})`

## Chewy 5/Elasticsearch 5 to Chewy 6/Elasticsearch 6

In order to upgrade Chewy 5/Elasticsearch 5 to Chewy 6/Elasticsearch 6 in the most seamless manner you have to:

* Upgrade to the latest 5.x stable releases, namely Chewy 5.2, Elasticsearch 5.6
* [Migrate any multi-typed indexes into single-typed](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/removal-of-types.html)
  * Using [multi-index queries](https://github.com/toptal/chewy/pull/657) could be helpful
  * Parent/Child [relationship is deprecated](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/removal-of-types.html#parent-child-mapping-types) in favor of the [join field](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/parent-join.html)
* Handle deprecation of `string` type & `not_analyzed` value for the `index` mapping parameter:
  * replace fields with `{ type: 'string', index: 'not_analyzed'}` by `{type: 'keyword'}`
  * replace fields with `{ type: 'string', index: 'analyzed'}` by `{type: 'text'}`
* `PathHierarchy` tokenizer' param `delimiter` now accepts only one argument, [others should be replaced by character filter ](https://discuss.elastic.co/t/multichar-delimiter-in-path-hierarchy-tokenizer/16203)
* Make sure you don't use any other of the [deprecated Elasticsearch 5 features](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/breaking-changes-6.0.html)
* Run your test suite on Chewy 6 / Elasticsearch 6
* Run manual tests on Chewy 6 / Elasticsearch 6
* Upgrade to Chewy 6
* Perform a [rolling upgrade](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/rolling-upgrades.html) of Elasticsearch

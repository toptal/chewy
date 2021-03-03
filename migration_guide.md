# Migration guide

This document outlines the steps you need to take when migrating between major versions of
Chewy and Elasticsearch. For simplicity's sake the guide will assume that you're using
Chewy alongside a matching Elasticsearch version.

## Chewy 6/Elasticsearch 6 to Chewy 7/Elasticsearch 7

In order to upgrade Chewy 6/Elasticsearch 6 to Chewy 7/Elasticsearch 7 in the most seamless manner you have to:

* Upgrade to the latest 6.x stable releases, namely Chewy 6.0, Elasticsearch 6.8
* Study carefully [Breaking changes in 7.0](https://www.elastic.co/guide/en/elasticsearch/reference/current/breaking-changes-7.0.htmll), make sure your application conforms.
* Run your test suite on Chewy 7.0 / Elasticsearch 7
* Run manual tests on Chewy 7.0 / Elasticsearch 7
* Upgrade to Chewy 7.0
* Perform a [rolling upgrade](https://www.elastic.co/guide/en/elasticsearch/reference//rolling-upgrades.html) of Elasticsearch
* Run your test suite on Chewy 7.1 / Elasticsearch 7
* Run manual tests on Chewy 7.1 / Elasticsearch 7
* Upgrade to Chewy 7.1

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

# Migration guide

## Chewy 5 / ES 5 to Chewy 6 / ES 6

In order to upgrade chewy5/ES5 to chewy6/ES6 in the most seamless manner you have to:
* Upgrade to the latest 5.x stable releases: Chewy 5.2, ES 5.6
* [Migrate any multi-typed indexes into single-typed](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/removal-of-types.html)
  * Using [multi-index queries](https://github.com/toptal/chewy/pull/657) could be helpful
  * Parent/Child [relationship is deprecated](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/removal-of-types.html#parent-child-mapping-types) in favor of the [join field](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/parent-join.html) 
* Handle deprecation of `string` type & `not_analyzed` value for the `index` mapping parameter:
  * replace fields with `{ type: 'string', index: 'not_analyzed'}` by `{type: 'keyword'}`
  * replace fields with `{ type: 'string', index: 'analyzed'}` by `{type: 'text'}`
* `PathHierarchy` tokenizer' param `delimiter` now accepts only one argument, [others should be replaced by character filter ](https://discuss.elastic.co/t/multichar-delimiter-in-path-hierarchy-tokenizer/16203)
* Make sure you don't use any other of the [deprecated ES5 features](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/breaking-changes-6.0.html)
* Run your test suite on ES6
* Run manual tests on ES6
* Perform a [rolling upgrade](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/rolling-upgrades.html) of Elasticsearch
* Upgrade to Chewy 6

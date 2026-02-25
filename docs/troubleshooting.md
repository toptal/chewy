# Troubleshooting

## Pre-request filter

Should you need to inspect the query prior to it being dispatched to Elasticsearch during any queries, you can use the `before_es_request_filter`. `before_es_request_filter` is a callable object, as demonstrated below:

```ruby
Chewy.before_es_request_filter = -> (method_name, args, kw_args) { ... }
```

While using the `before_es_request_filter`, please consider the following:

* `before_es_request_filter` acts as a simple proxy before any request made via the    `Elasticsearch::Client`. The arguments passed to this filter include:
  * `method_name` -  The name of the method being called. Examples are search, count, bulk and etc.
  * `args` and `kw_args` - These are the positional arguments provided in the method call.
* The operation is synchronous, so avoid executing any heavy or time-consuming operations within the filter to prevent performance degradation.
* The return value of the proc is disregarded. This filter is intended for inspection or modification of the query rather than generating a response.
* Any exception raised inside the callback will propagate upward and halt the execution of the query. It is essential to handle potential errors adequately to ensure the stability of your search functionality.

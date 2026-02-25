# Troubleshooting

## `UndefinedUpdateStrategy` error

This is the most common Chewy error. When you save a model that has an `update_index` callback and no update strategy is active, Chewy raises `Chewy::UndefinedUpdateStrategy`:

```
Index update strategy is undefined for current context.
Please wrap your code with `Chewy.strategy(:strategy_name)` block.
```

**Fix:** wrap the code that triggers the save in a strategy block:

```ruby
Chewy.strategy(:atomic) do
  city.save!
end
```

In a Rails app, controller actions already use the `:atomic` strategy by default. This error typically appears in background jobs, rake tasks, or console sessions. For console use, you can set `:urgent` as a persistent strategy:

```ruby
Chewy.strategy(:urgent)
```

If you want to suppress index updates entirely (e.g. in tests or migrations), use `:bypass`:

```ruby
Chewy.root_strategy = :bypass
```

See [configuration.md](configuration.md#index-update-strategies) for the full list of strategies.

## Elasticsearch 8 security defaults

Elasticsearch 8 enables security (TLS + authentication) by default. If you see connection refused or authentication errors after upgrading, you need to configure credentials and the CA certificate. See the [Security section](../README.md#security) in the main README for setup instructions.

## Wildcard index deletion disabled in ES 8

Starting from Elasticsearch 8, wildcard deletion of indices is disabled by default. If `Chewy.massacre` or other bulk-delete operations fail with a `Chewy::FeatureDisabled` error, you need to set the cluster setting `action.destructive_requires_name` to `false`:

```
PUT _cluster/settings
{ "persistent": { "action.destructive_requires_name": false } }
```

## Import errors and debugging

When using `import!` (with a bang), Chewy raises `Chewy::ImportFailed` if any documents fail to index. The error message groups failures by action type (index, delete) and includes the document IDs:

```
Import failed for `ProductsIndex` with:
    Index errors:
      `mapper_parsing_exception`
        on 3 documents: ["1", "2", "3"]
```

For non-bang `import`, errors are silently swallowed. To debug import issues, set up a logger:

```ruby
Chewy.logger = Logger.new(STDOUT)
```

You can also subscribe to `import_objects.chewy` notifications — see [configuration.md](configuration.md#activesupportnotifications-support) for the payload format.

## Import scope cleanup warnings

When an `index_scope` includes `order`, `limit`, or `offset`, Chewy strips them before importing (they don't make sense for batch processing). By default this logs a warning. If you see unexpected warnings during import, you can control this via:

```ruby
Chewy.import_scope_cleanup_behavior = :ignore # no warning
Chewy.import_scope_cleanup_behavior = :raise   # raise Chewy::ImportScopeCleanupError
```

See [configuration.md](configuration.md#import-scope-clean-up-behavior) for details.

## Missing optional dependencies

Some Chewy features require additional gems that are not listed as hard dependencies:

- **`parallel`** — required for `chewy:parallel:*` rake tasks. Install it with `gem 'parallel'` in your Gemfile.
- **`method_source`** — required for the Witchcraft technology (compiled value procs). Install it with `gem 'method_source'`.

If these gems are missing you'll get a `LoadError` when the relevant feature is used.

## Pre-request filter

Should you need to inspect the query prior to it being dispatched to Elasticsearch during any queries, you can use the `before_es_request_filter`. `before_es_request_filter` is a callable object, as demonstrated below:

```ruby
Chewy.before_es_request_filter = -> (method_name, args, kw_args) { ... }
```

While using the `before_es_request_filter`, please consider the following:

* `before_es_request_filter` acts as a simple proxy before any request made via the `Elasticsearch::Client`. The arguments passed to this filter include:
  * `method_name` — the name of the method being called (e.g. search, count, bulk).
  * `args` and `kw_args` — the positional and keyword arguments provided in the method call.
* The operation is synchronous, so avoid executing any heavy or time-consuming operations within the filter to prevent performance degradation.
* The return value of the proc is disregarded. This filter is intended for inspection or modification of the query rather than generating a response.
* Any exception raised inside the callback will propagate upward and halt the execution of the query. It is essential to handle potential errors adequately to ensure the stability of your search functionality.

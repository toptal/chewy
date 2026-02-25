# Rake Tasks

For a Rails application, some index-maintaining rake tasks are defined.

## `chewy:reset`

Performs zero-downtime reindexing as described [here](https://www.elastic.co/blog/changing-mapping-with-zero-downtime). So the rake task creates a new index with unique suffix and then simply aliases it to the common index name. The previous index is deleted afterwards (see `Chewy::Index.reset!` for more details).

```bash
rake chewy:reset # resets all the existing indices
rake chewy:reset[users] # resets UsersIndex only
rake chewy:reset[users,cities] # resets UsersIndex and CitiesIndex
rake chewy:reset[-users,cities] # resets every index in the application except specified ones
```

## `chewy:upgrade`

Performs reset exactly the same way as `chewy:reset` does, but only when the index specification (setting or mapping) was changed.

It works only when index specification is locked in `Chewy::Stash::Specification` index. The first run will reset all indexes and lock their specifications.

See [Chewy::Stash::Specification](../lib/chewy/stash.rb) and [Chewy::Index::Specification](../lib/chewy/index/specification.rb) for more details.


```bash
rake chewy:upgrade # upgrades all the existing indices
rake chewy:upgrade[users] # upgrades UsersIndex only
rake chewy:upgrade[users,cities] # upgrades UsersIndex and CitiesIndex
rake chewy:upgrade[-users,cities] # upgrades every index in the application except specified ones
```

## `chewy:update`

It doesn't create indexes, it simply imports everything to the existing ones and fails if the index was not created before.

```bash
rake chewy:update # updates all the existing indices
rake chewy:update[users] # updates UsersIndex only
rake chewy:update[users,cities] # updates UsersIndex and CitiesIndex
rake chewy:update[-users,cities] # updates every index in the application except UsersIndex and CitiesIndex
```

## `chewy:sync`

Provides a way to synchronize outdated indexes with the source quickly and without doing a full reset. By default field `updated_at` is used to find outdated records, but this could be customized by `outdated_sync_field` as described at [Chewy::Index::Syncer](../lib/chewy/index/syncer.rb).

Arguments are similar to the ones taken by `chewy:update` task.

See [Chewy::Index::Syncer](../lib/chewy/index/syncer.rb) for more details.

```bash
rake chewy:sync # synchronizes all the existing indices
rake chewy:sync[users] # synchronizes UsersIndex only
rake chewy:sync[users,cities] # synchronizes UsersIndex and CitiesIndex
rake chewy:sync[-users,cities] # synchronizes every index in the application except UsersIndex and CitiesIndex
```

## `chewy:deploy`

This rake task is especially useful during the production deploy. It is a combination of `chewy:upgrade` and `chewy:sync` and the latter is called only for the indexes that were not reset during the first stage.

It is not possible to specify any particular indexes for this task as it doesn't make much sense.

Right now the approach is that if some data had been updated, but index definition was not changed (no changes satisfying the synchronization algorithm were done), it would be much faster to perform manual partial index update inside data migrations or even manually after the deploy.

Also, there is always full reset alternative with `rake chewy:reset`.

## `chewy:create_missing_indexes`

This rake task creates newly defined indexes in Elasticsearch and skips existing ones. Useful for production-like environments.

## Parallelizing rake tasks

Every task described above has its own parallel version. Every parallel rake task takes the number for processes for execution as the first argument and the rest of the arguments are exactly the same as for the non-parallel task version.

[https://github.com/grosser/parallel](https://github.com/grosser/parallel) gem is required to use these tasks.

If the number of processes is not specified explicitly - `parallel` gem tries to automatically derive the number of processes to use.

```bash
rake chewy:parallel:reset
rake chewy:parallel:upgrade[4]
rake chewy:parallel:update[4,cities]
rake chewy:parallel:sync[4,-users]
rake chewy:parallel:deploy[4] # performs parallel upgrade and parallel sync afterwards
```

## `chewy:journal`

This namespace contains two tasks for the journal manipulations: `chewy:journal:apply` and `chewy:journal:clean`. Both are taking time as the first argument (optional for clean) and a list of indexes exactly as the tasks above. Time can be in any format parsable by ActiveSupport.

```bash
rake chewy:journal:apply["$(date -v-1H -u +%FT%TZ)"] # apply journaled changes for the past hour
rake chewy:journal:apply["$(date -v-1H -u +%FT%TZ)",users] # apply journaled changes for the past hour on UsersIndex only
```

When the size of the journal becomes very large, the classical way of deletion would be obstructive and resource consuming. Fortunately, Chewy internally uses [delete-by-query](https://www.elastic.co/guide/en/elasticsearch/reference/7.17/docs-delete-by-query.html#docs-delete-by-query-task-api) ES function which supports async execution with batching and [throttling](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-delete-by-query.html#docs-delete-by-query-throttle).

The available options, which can be set by ENV variables, are listed below:
* `WAIT_FOR_COMPLETION` - a boolean flag. It controls async execution. It waits by default. When set to `false` (`0`, `f`, `false` or `off` in any case spelling is accepted as `false`), Elasticsearch performs some preflight checks, launches the request, and returns a task reference you can use to cancel the task or get its status.
* `REQUESTS_PER_SECOND` - float. The throttle for this request in sub-requests per second. No throttling is enforced by default.
* `SCROLL_SIZE` - integer. The number of documents to be deleted in single sub-request. The default batch size is 1000.

```bash
rake chewy:journal:clean WAIT_FOR_COMPLETION=false REQUESTS_PER_SECOND=10 SCROLL_SIZE=5000
```

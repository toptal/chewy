# Configuration

## Client settings

To configure the Chewy client you need to add `chewy.rb` file with `Chewy.settings` hash:

```ruby
# config/initializers/chewy.rb
Chewy.settings = {host: 'localhost:9250'} # do not use environments
```

And add `chewy.yml` configuration file.

You can create `chewy.yml` manually or run `rails g chewy:install` to generate it:

```yaml
# config/chewy.yml
# separate environment configs
test:
  host: 'localhost:9250'
  prefix: 'test'
development:
  host: 'localhost:9200'
```

The resulting config merges both hashes. Client options are passed as is to `Elasticsearch::Transport::Client` except for the `:prefix`, which is used internally by Chewy to create prefixed index names:

```ruby
  Chewy.settings = {prefix: 'test'}
  UsersIndex.index_name # => 'test_users'
```

The logger may be set explicitly:

```ruby
Chewy.logger = Logger.new(STDOUT)
```

See [config.rb](../lib/chewy/config.rb) for more details.

### AWS Elasticsearch

If you would like to use AWS's Elasticsearch using an IAM user policy, you will need to sign your requests for the `es:*` action by injecting the appropriate headers passing a proc to `transport_options`.
You'll need an additional gem for Faraday middleware: add `gem 'faraday_middleware-aws-sigv4'` to your Gemfile.

```ruby
require 'faraday_middleware/aws_sigv4'

Chewy.settings = {
  host: 'http://my-es-instance-on-aws.us-east-1.es.amazonaws.com:80',
  port: 80, # 443 for https host
  transport_options: {
    headers: { content_type: 'application/json' },
    proc: -> (f) do
        f.request :aws_sigv4,
                  service: 'es',
                  region: 'us-east-1',
                  access_key_id: ENV['AWS_ACCESS_KEY'],
                  secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
    end
  }
}
```

## Elasticsearch client options

All connection options, except the `:prefix`, are passed to the `Elasticseach::Client.new` ([chewy/lib/chewy.rb](https://github.com/toptal/chewy/blob/f5bad9f83c21416ac10590f6f34009c645062e89/lib/chewy.rb#L153-L160)):

Here's the relevant Elasticsearch documentation on the subject: https://rubydoc.info/gems/elasticsearch-transport#setting-hosts

## Index update strategies

Assume you've got the following code (see [indexing.md](indexing.md#index-definition) for the full `update_index` DSL):

```ruby
class City < ActiveRecord::Base
  update_index 'cities', :self
end

class CitiesIndex < Chewy::Index
  index_scope City
  field :name
end
```

If you do something like `City.first.save!` you'll get an UndefinedUpdateStrategy exception instead of the object saving and index updating. This exception forces you to choose an appropriate update strategy for the current context.

If you want to return to the pre-0.7.0 behavior - just set `Chewy.root_strategy = :bypass`.

### `:atomic`

The main strategy here is `:atomic`. Assume you have to update a lot of records in the db.

```ruby
Chewy.strategy(:atomic) do
  City.popular.map(&:do_some_update_action!)
end
```

Using this strategy delays the index update request until the end of the block. Updated records are aggregated and the index update happens with the bulk API. So this strategy is highly optimized.

### `:sidekiq`

This does the same thing as `:atomic`, but asynchronously using sidekiq. Patch `Chewy::Strategy::Sidekiq::Worker` for index updates improving.

```ruby
Chewy.strategy(:sidekiq) do
  City.popular.map(&:do_some_update_action!)
end
```

The default queue name is `chewy`, you can customize it in settings: `sidekiq.queue_name`
```
Chewy.settings[:sidekiq] = {queue: :low}
```

### `:lazy_sidekiq`

This does the same thing as `:sidekiq`, but with lazy evaluation. Beware it does not allow you to use any non-persistent record state for indices and conditions because record will be re-fetched from database asynchronously using sidekiq. However for destroying records strategy will fallback to `:sidekiq` because it's not possible to re-fetch deleted records from database.

The purpose of this strategy is to improve the response time of the code that should update indexes, as it does not only defer actual ES calls to a background job but `update_index` callbacks evaluation (for created and updated objects) too. Similar to `:sidekiq`, index update is asynchronous so this strategy cannot be used when data and index synchronization is required.

```ruby
Chewy.strategy(:lazy_sidekiq) do
  City.popular.map(&:do_some_update_action!)
end
```

The default queue name is `chewy`, you can customize it in settings: `sidekiq.queue_name`
```
Chewy.settings[:sidekiq] = {queue: :low}
```

### `:delayed_sidekiq`

It accumulates IDs of records to be reindexed during the latency window in Redis and then performs the reindexing of all accumulated records at once.
This strategy is very useful in the case of frequently mutated records.
It supports the `update_fields` option, so it will attempt to select just enough data from the database.

Keep in mind, this strategy does not guarantee reindexing in the event of Sidekiq worker termination or an error during the reindexing phase.
This behavior is intentional to prevent continuous growth of Redis db.

There are three options that can be defined in the index:
```ruby
class CitiesIndex...
  strategy_config delayed_sidekiq: {
    latency: 3,
    margin: 2,
    ttl: 60 * 60 * 24,
    reindex_wrapper: ->(&reindex) {
      ActiveRecord::Base.connected_to(role: :reading) { reindex.call }
    }
    # latency - will prevent scheduling identical jobs
    # margin - main purpose is to cover db replication lag by the margin
    # ttl - a chunk expiration time (in seconds)
    # reindex_wrapper - lambda that accepts block to wrap that reindex process AR connection block.
  }

  ...
end
```

Also you can define defaults in the `initializers/chewy.rb`
```ruby
Chewy.settings = {
  strategy_config: {
    delayed_sidekiq: {
      latency: 3,
      margin: 2,
      ttl: 60 * 60 * 24,
      reindex_wrapper: ->(&reindex) {
        ActiveRecord::Base.connected_to(role: :reading) { reindex.call }
      }
    }
  }
}

```
or in `config/chewy.yml`
```ruby
  strategy_config:
    delayed_sidekiq:
      latency: 3
      margin: 2
      ttl: <%= 60 * 60 * 24 %>
      # reindex_wrapper setting is not possible here!!! use the initializer instead
```

You can use the strategy identically to other strategies
```ruby
Chewy.strategy(:delayed_sidekiq) do
  City.popular.map(&:do_some_update_action!)
end
```

The default queue name is `chewy`, you can customize it in settings: `sidekiq.queue_name`
```
Chewy.settings[:sidekiq] = {queue: :low}
```

Explicit call of the reindex using `:delayed_sidekiq strategy`
```ruby
CitiesIndex.import([1, 2, 3], strategy: :delayed_sidekiq)
```

Explicit call of the reindex using `:delayed_sidekiq` strategy with `:update_fields` support
```ruby
CitiesIndex.import([1, 2, 3], update_fields: [:name], strategy: :delayed_sidekiq)
```

While running tests with delayed_sidekiq strategy and Sidekiq is using a real redis instance that is NOT cleaned up in between tests (via e.g. `Sidekiq.redis(&:flushdb)`), you'll want to cleanup some redis keys in between tests to avoid state leaking and flaky tests. Chewy provides a convenience method for that:
```ruby
# it might be a good idea to also add to your testing setup, e.g.: a rspec `before` hook
Chewy::Strategy::DelayedSidekiq.clear_timechunks!
```

### `:active_job`

This does the same thing as `:atomic`, but using ActiveJob. This will inherit the ActiveJob configuration settings including the `active_job.queue_adapter` setting for the environment. Patch `Chewy::Strategy::ActiveJob::Worker` for index updates improving.

```ruby
Chewy.strategy(:active_job) do
  City.popular.map(&:do_some_update_action!)
end
```

The default queue name is `chewy`, you can customize it in settings: `active_job.queue_name`
```
Chewy.settings[:active_job] = {queue: :low}
```

### `:urgent`

The following strategy is convenient if you are going to update documents in your index one by one.

```ruby
Chewy.strategy(:urgent) do
  City.popular.map(&:do_some_update_action!)
end
```

This code will perform `City.popular.count` requests for ES documents update.

It is convenient for use in e.g. the Rails console with non-block notation:

```ruby
> Chewy.strategy(:urgent)
> City.popular.map(&:do_some_update_action!)
```

### `:bypass`

When the bypass strategy is active the index will not be automatically updated on object save.

For example, on `City.first.save!` the cities index would not be updated.

### Nesting

Strategies are designed to allow nesting, so it is possible to redefine it for nested contexts.

```ruby
Chewy.strategy(:atomic) do
  city1.do_update!
  Chewy.strategy(:urgent) do
    city2.do_update!
    city3.do_update!
    # there will be 2 update index requests for city2 and city3
  end
  city4.do_update!
  # city1 and city4 will be grouped in one index update request
end
```

### Non-block notation

It is possible to nest strategies without blocks:

```ruby
Chewy.strategy(:urgent)
city1.do_update! # index updated
Chewy.strategy(:bypass)
city2.do_update! # update bypassed
Chewy.strategy.pop
city3.do_update! # index updated again
```

### Designing your own strategies

See [strategy/base.rb](../lib/chewy/strategy/base.rb) for more details. See [strategy/atomic.rb](../lib/chewy/strategy/atomic.rb) for an example.

## Rails application strategies integration

There are a couple of predefined strategies for your Rails application. Initially, the Rails console uses the `:urgent` strategy by default, except in the sandbox case. When you are running sandbox it switches to the `:bypass` strategy to avoid polluting the index.

Migrations are wrapped with the `:bypass` strategy. Because the main behavior implies that indices are reset after migration, there is no need for extra index updates. Also indexing might be broken during migrations because of the outdated schema.

Controller actions are wrapped with the configurable value of `Chewy.request_strategy` and defaults to `:atomic`. This is done at the middleware level to reduce the number of index update requests inside actions.

It is also a good idea to set up the `:bypass` strategy inside your test suite and import objects manually only when needed, and use `Chewy.massacre` when needed to flush test ES indices before every example. This will allow you to minimize unnecessary ES requests and reduce overhead.

Deprecation note: since version 8 wildcard removing of indices is disabled by default. You can enable it for a cluster with setting `action.destructive_requires_name` to false.

```ruby
RSpec.configure do |config|
  config.before(:suite) do
    Chewy.strategy(:bypass)
  end
end
```

See [testing.md](testing.md) for more on RSpec/Minitest integration and the DatabaseCleaner caveat.

## `ActiveSupport::Notifications` support

Chewy has notifying the following events:

### `search_query.chewy` payload

  * `payload[:index]`: requested index class
  * `payload[:request]`: request hash

### `import_objects.chewy` payload

  * `payload[:index]`: currently imported index name
  * `payload[:import]`: imports stats, total imported and deleted objects count:

    ```ruby
    {index: 30, delete: 5}
    ```

  * `payload[:errors]`: might not exist. Contains grouped errors with objects ids list:

    ```ruby
    {index: {
      'error 1 text' => ['1', '2', '3'],
      'error 2 text' => ['4']
    }, delete: {
      'delete error text' => ['10', '12']
    }}
    ```

## NewRelic integration

**Note:** this example was written for an older version of the NewRelic APM agent and may need adaptation for current versions. The general pattern of subscribing to Chewy's `ActiveSupport::Notifications` events remains valid.

To integrate with NewRelic you may use the following example source (config/initializers/chewy.rb):

```ruby
require 'new_relic/agent/instrumentation/evented_subscriber'

class ChewySubscriber < NewRelic::Agent::Instrumentation::EventedSubscriber
  def start(name, id, payload)
    event = ChewyEvent.new(name, Time.current, nil, id, payload)
    push_event(event)
  end

  def finish(_name, id, _payload)
    pop_event(id).finish
  end

  class ChewyEvent < NewRelic::Agent::Instrumentation::Event
    OPERATIONS = {
      'import_objects.chewy' => 'import',
      'search_query.chewy' => 'search',
      'delete_query.chewy' => 'delete'
    }.freeze

    def initialize(*args)
      super
      @segment = start_segment
    end

    def start_segment
      segment = NewRelic::Agent::Transaction::DatastoreSegment.new product, operation, collection, host, port
      if (txn = state.current_transaction)
        segment.transaction = txn
      end
      segment.notice_sql @payload[:request].to_s
      segment.start
      segment
    end

    def finish
      if (txn = state.current_transaction)
        txn.add_segment @segment
      end
      @segment.finish
    end

    private

    def state
      @state ||= NewRelic::Agent::TransactionState.tl_get
    end

    def product
      'Elasticsearch'
    end

    def operation
      OPERATIONS[name]
    end

    def collection
      payload.values_at(:type, :index)
             .reject { |value| value.try(:empty?) }
             .first
             .to_s
    end

    def host
      Chewy.client.transport.hosts.first[:host]
    end

    def port
      Chewy.client.transport.hosts.first[:port]
    end
  end
end

ActiveSupport::Notifications.subscribe(/.chewy$/, ChewySubscriber.new)
```

## Import scope clean-up behavior

Whenever you set the `import_scope` for the index, in the case of ActiveRecord,
options for order, offset and limit will be removed. You can set the behavior of
chewy, before the clean-up itself.

The default behavior is a warning sent to the Chewy logger (`:warn`). Another more
restrictive option is raising an exception (`:raise`). Both options have a
negative impact on performance since verifying whether the code uses any of
these options requires building AREL query.

To avoid the loading time impact, you can ignore the check (`:ignore`) before
the clean-up.

```
Chewy.import_scope_cleanup_behavior = :ignore
```

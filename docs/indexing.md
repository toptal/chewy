# Indexing

## Index definition

1. Create `/app/chewy/users_index.rb`

  ```ruby
  class UsersIndex < Chewy::Index

  end
  ```

2. Define index scope (you can omit this part if you don't need to specify a scope (i.e. use PORO objects for import) or options)

  ```ruby
  class UsersIndex < Chewy::Index
    index_scope User.active # or just model instead_of scope: index_scope User
  end
  ```

3. Add some mappings

  ```ruby
  class UsersIndex < Chewy::Index
    index_scope User.active.includes(:country, :badges, :projects)
    field :first_name, :last_name # multiple fields without additional options
    field :email, analyzer: 'email' # Elasticsearch-related options
    field :country, value: ->(user) { user.country.name } # custom value proc
    field :badges, value: ->(user) { user.badges.map(&:name) } # passing array values to index
    field :projects do # the same block syntax for multi_field, if `:type` is specified
      field :title
      field :description # default data type is `text`
      # additional top-level objects passed to value proc:
      field :categories, value: ->(project, user) { project.categories.map(&:name) if user.active? }
    end
    field :rating, type: 'integer' # custom data type
    field :created, type: 'date', include_in_all: false,
      value: ->{ created_at } # value proc for source object context
  end
  ```

  [See here for mapping definitions](https://www.elastic.co/guide/en/elasticsearch/reference/current/mapping.html).

4. Add some index-related settings. Analyzer repositories might be used as well. See `Chewy::Index.settings` docs for details:

  ```ruby
  class UsersIndex < Chewy::Index
    settings analysis: {
      analyzer: {
        email: {
          tokenizer: 'keyword',
          filter: ['lowercase']
        }
      }
    }

    index_scope User.active.includes(:country, :badges, :projects)
    root date_detection: false do
      template 'about_translations.*', type: 'text', analyzer: 'standard'

      field :first_name, :last_name
      field :email, analyzer: 'email'
      field :country, value: ->(user) { user.country.name }
      field :badges, value: ->(user) { user.badges.map(&:name) }
      field :projects do
        field :title
        field :description
      end
      field :about_translations, type: 'object' # pass object type explicitly if necessary
      field :rating, type: 'integer'
      field :created, type: 'date', include_in_all: false,
        value: ->{ created_at }
    end
  end
  ```

  [See index settings here](https://www.elastic.co/guide/en/elasticsearch/reference/current/indices-update-settings.html).
  [See root object settings here](https://www.elastic.co/guide/en/elasticsearch/reference/current/dynamic-field-mapping.html).

  See [mapping.rb](../lib/chewy/index/mapping.rb) for more details.

5. Add model-observing code

  ```ruby
  class User < ActiveRecord::Base
    update_index('users') { self } # specifying index and back-reference
                                        # for updating after user save or destroy
  end

  class Country < ActiveRecord::Base
    has_many :users

    update_index('users') { users } # return single object or collection
  end

  class Project < ActiveRecord::Base
    update_index('users') { user if user.active? } # you can return even `nil` from the back-reference
  end

  class Book < ActiveRecord::Base
    update_index(->(book) {"books_#{book.language}"}) { self } # dynamic index name with proc.
                                                               # For book with language == "en"
                                                               # this code will generate `books_en`
  end
  ```

  The `update_index` callback requires an active update strategy to be set. See [configuration.md](configuration.md#index-update-strategies) for available strategies and how they integrate with Rails.

  Also, you can use the second argument for method name passing:

  ```ruby
  update_index('users', :self)
  update_index('users', :users)
  ```

  In the case of a belongs_to association you may need to update both associated objects, previous and current:

  ```ruby
  class City < ActiveRecord::Base
    belongs_to :country

    update_index('cities') { self }
    update_index 'countries' do
      previous_changes['country_id'] || country
    end
  end
  ```

## Multi (nested) and object field types

To define an objects field you can simply nest fields in the DSL:

```ruby
field :projects do
  field :title
  field :description
end
```

This will automatically set the type or root field to `object`. You may also specify `type: 'objects'` explicitly.

To define a multi field you have to specify any type except for `object` or `nested` in the root field:

```ruby
field :full_name, type: 'text', value: ->{ full_name.strip } do
  field :ordered, analyzer: 'ordered'
  field :untouched, type: 'keyword'
end
```

The `value:` option for internal fields will no longer be effective.

## Geo Point fields

You can use [Elasticsearch's geo mapping](https://www.elastic.co/guide/en/elasticsearch/reference/current/geo-point.html) with the `geo_point` field type, allowing you to query, filter and order by latitude and longitude. You can use the following hash format:

```ruby
field :coordinates, type: 'geo_point', value: ->{ {lat: latitude, lon: longitude} }
```

or by using nested fields:

```ruby
field :coordinates, type: 'geo_point' do
  field :lat, value: ->{ latitude }
  field :long, value: ->{ longitude }
end
```

See the section on *Script fields* for details on calculating distance in a search.

## Join fields

You can use a [join field](https://www.elastic.co/guide/en/elasticsearch/reference/current/parent-join.html)
to implement parent-child relationships between documents.
It [replaces the old `parent_id` based parent-child mapping](https://www.elastic.co/guide/en/elasticsearch/reference/current/removal-of-types.html#parent-child-mapping-types)

To use it, you need to pass `relations` and `join` (with `type` and `id`) options:
```ruby
field :hierarchy_link, type: :join, relations: {question: %i[answer comment], answer: :vote, vote: :subvote}, join: {type: :comment_type, id: :commented_id}
```
assuming you have `comment_type` and `commented_id` fields in your model.

Note that when you reindex a parent, its children and grandchildren will be reindexed as well.
This may require additional queries to the primary database and to Elasticsearch.

Also note that the join field doesn't support crutches (it should be a field directly defined on the model).

## Crutches technology

Assume you are defining your index like this (product has_many categories through product_categories):

```ruby
class ProductsIndex < Chewy::Index
  index_scope Product.includes(:categories)
  field :name
  field :category_names, value: ->(product) { product.categories.map(&:name) } # or shorter just -> { categories.map(&:name) }
end
```

Then the Chewy reindexing flow will look like the following pseudo-code:

```ruby
Product.includes(:categories).find_in_batches(1000) do |batch|
  bulk_body = batch.map do |object|
    {name: object.name, category_names: object.categories.map(&:name)}.to_json
  end
  # here we are sending every batch of data to ES
  Chewy.client.bulk bulk_body
end
```

If you meet complicated cases when associations are not applicable you can replace Rails associations with Chewy Crutches technology:

```ruby
class ProductsIndex < Chewy::Index
  index_scope Product
  crutch :categories do |collection| # collection here is a current batch of products
    # data is fetched with a lightweight query without objects initialization
    data = ProductCategory.joins(:category).where(product_id: collection.map(&:id)).pluck(:product_id, 'categories.name')
    # then we have to convert fetched data to appropriate format
    # this will return our data in structure like:
    # {123 => ['sweets', 'juices'], 456 => ['meat']}
    data.each.with_object({}) { |(id, name), result| (result[id] ||= []).push(name) }
  end

  field :name
  # simply use crutch-fetched data as a value:
  field :category_names, value: ->(product, crutches) { crutches[:categories][product.id] }
end
```

An example flow will look like this:

```ruby
Product.includes(:categories).find_in_batches(1000) do |batch|
  crutches[:categories] = ProductCategory.joins(:category).where(product_id: batch.map(&:id)).pluck(:product_id, 'categories.name')
    .each.with_object({}) { |(id, name), result| (result[id] ||= []).push(name) }

  bulk_body = batch.map do |object|
    {name: object.name, category_names: crutches[:categories][object.id]}.to_json
  end
  Chewy.client.bulk bulk_body
end
```

So Chewy Crutches technology is able to increase your indexing performance in some cases up to a hundredfold or even more depending on your associations complexity. For another approach to import performance, see [Raw import](import.md#raw-import).

## Witchcraft technology

One more experimental technology to increase import performance. As far as you know, chewy defines value proc for every imported field in mapping, so at the import time each of these procs is executed on imported object to extract result document to import. It would be great for performance to use one huge whole-document-returning proc instead. So basically the idea or Witchcraft technology is to compile a single document-returning proc from the index definition.

```ruby
index_scope Product
witchcraft!

field :title
field :tags, value: -> { tags.map(&:name) }
field :categories do
  field :name, value: -> (product, category) { category.name }
  field :type, value: -> (product, category, crutch) { crutch.types[category.name] }
end
```

The index definition above will be compiled to something close to:

```ruby
-> (object, crutches) do
  {
    title: object.title,
    tags: object.tags.map(&:name),
    categories: object.categories.map do |object2|
      {
        name: object2.name
        type: crutches.types[object2.name]
      }
    end
  }
end
```

And don't even ask how is it possible, it is a witchcraft.
Obviously not every type of definition might be compiled. There are some restrictions:

1. Use reasonable formatting to make `method_source` be able to extract field value proc sources.
2. Value procs with splat arguments are not supported right now.
3. If you are generating fields dynamically use value proc with arguments, argumentless value procs are not supported yet:

  ```ruby
  [:first_name, :last_name].each do |name|
    field name, value: -> (o) { o.send(name) }
  end
  ```

However, it is quite possible that your index definition will be supported by Witchcraft technology out of the box in most of the cases.

## Index manipulation

```ruby
UsersIndex.delete # destroy index if it exists
UsersIndex.delete!

UsersIndex.create
UsersIndex.create! # use bang or non-bang methods

UsersIndex.purge
UsersIndex.purge! # deletes then creates index

UsersIndex.import # import with 0 arguments process all the data specified in index_scope definition
UsersIndex.import User.where('rating > 100') # or import specified users scope
UsersIndex.import User.where('rating > 100').to_a # or import specified users array
UsersIndex.import [1, 2, 42] # pass even ids for import, it will be handled in the most effective way
UsersIndex.import User.where('rating > 100'), update_fields: [:email] # if update fields are specified - it will update their values only with the `update` bulk action
UsersIndex.import! # raises an exception in case of any import errors

UsersIndex.reset! # purges index and imports default data for all types
```

For more on import options, batching and journaling, see [import.md](import.md).

If the passed user is `#destroyed?`, or satisfies a `delete_if` index_scope option, or the specified id does not exist in the database, import will perform delete from index action for this object.

```ruby
index_scope User, delete_if: :deleted_at
index_scope User, delete_if: -> { deleted_at }
index_scope User, delete_if: ->(user) { user.deleted_at }
```

See [actions.rb](../lib/chewy/index/actions.rb) for more details.

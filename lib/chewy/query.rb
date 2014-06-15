require 'chewy/query/criteria'
require 'chewy/query/filters'
require 'chewy/query/loading'
require 'chewy/query/pagination'

module Chewy
  # Query allows you to create ES search requests with convenient
  # chainable DSL. Queries are lazy evaluated and might be merged.
  # The same DSL is used for whole index or individual types query build.
  #
  #   UsersIndex.filter{ age < 42 }.query(text: {name: 'Alex'}).limit(20)
  #   UsersIndex::User.filter{ age < 42 }.query(text: {name: 'Alex'}).limit(20)
  #
  class Query
    include Enumerable
    include Loading
    include Pagination

    delegate :each, :count, :size, to: :_results
    alias_method :to_ary, :to_a

    attr_reader :index, :options, :criteria

    def initialize index, options = {}
      @index, @options = index, options
      @types = Array.wrap(options.delete(:types))
      @criteria = Criteria.new
      reset
    end

    # Comparation with other query or collection
    # If other is collection - search request is executed and
    # result is used for comparation
    #
    #   UsersIndex.filter(term: {name: 'Johny'}) == UsersIndex.filter(term: {name: 'Johny'}) # => true
    #   UsersIndex.filter(term: {name: 'Johny'}) == UsersIndex.filter(term: {name: 'Johny'}).to_a # => true
    #   UsersIndex.filter(term: {name: 'Johny'}) == UsersIndex.filter(term: {name: 'Winnie'}) # => false
    #
    def == other
      super || if other.is_a?(self.class)
        other.criteria == criteria
      else
        to_a == other
      end
    end

    # Adds <tt>explain</tt> parameter to search request.
    #
    #   UsersIndex.filter(term: {name: 'Johny'}).explain
    #   UsersIndex.filter(term: {name: 'Johny'}).explain(true)
    #   UsersIndex.filter(term: {name: 'Johny'}).explain(false)
    #
    # Calling explain without any arguments sets explanation flag to true.
    # With <tt>explain: true</tt>, every result object has <tt>_explanation</tt>
    # method
    #
    #   UsersIndex::User.filter(term: {name: 'Johny'}).explain.first._explanation # => {...}
    #
    def explain value = nil
      chain { criteria.update_request_options explain: (value.nil? ? true : value) }
    end

    # Sets query compilation mode for search request.
    # Not used if only one filter for search is specified.
    # Possible values:
    #
    # * <tt>:must</tt>
    #   Default value. Query compiles into a bool <tt>must</tt> query.
    #
    #   Ex:
    #
    #     UsersIndex.query(text: {name: 'Johny'}).query(range: {age: {lte: 42}})
    #       # => {body: {
    #              query: {bool: {must: [{text: {name: 'Johny'}}, {range: {age: {lte: 42}}}]}}
    #            }}
    #
    # * <tt>:should</tt>
    #   Query compiles into a bool <tt>should</tt> query.
    #
    #   Ex:
    #
    #     UsersIndex.query(text: {name: 'Johny'}).query(range: {age: {lte: 42}}).query_mode(:should)
    #       # => {body: {
    #              query: {bool: {should: [{text: {name: 'Johny'}}, {range: {age: {lte: 42}}}]}}
    #            }}
    #
    # * Any acceptable <tt>minimum_should_match</tt> value (1, '2', '75%')
    #   Query compiles into a bool <tt>should</tt> query with <tt>minimum_should_match</tt> set.
    #
    #   Ex:
    #
    #     UsersIndex.query(text: {name: 'Johny'}).query(range: {age: {lte: 42}}).query_mode('50%')
    #       # => {body: {
    #              query: {bool: {
    #                should: [{text: {name: 'Johny'}}, {range: {age: {lte: 42}}}],
    #                minimum_should_match: '50%'
    #              }}
    #            }}
    #
    # * <tt>:dis_max</tt>
    #   Query compiles into a <tt>dis_max</tt> query.
    #
    #   Ex:
    #
    #     UsersIndex.query(text: {name: 'Johny'}).query(range: {age: {lte: 42}}).query_mode(:dis_max)
    #       # => {body: {
    #              query: {dis_max: {queries: [{text: {name: 'Johny'}}, {range: {age: {lte: 42}}}]}}
    #            }}
    #
    # * Any Float value (0.0, 0.7, 1.0)
    #   Query compiles into a <tt>dis_max</tt> query with <tt>tie_breaker</tt> option set.
    #
    #   Ex:
    #
    #     UsersIndex.query(text: {name: 'Johny'}).query(range: {age: {lte: 42}}).query_mode(0.7)
    #       # => {body: {
    #              query: {dis_max: {
    #                queries: [{text: {name: 'Johny'}}, {range: {age: {lte: 42}}}],
    #                tie_breaker: 0.7
    #              }}
    #            }}
    #
    # Default value for <tt>:query_mode</tt> might be changed
    # with <tt>Chewy.query_mode</tt> config option.
    #
    #   Chewy.query_mode = :dis_max
    #   Chewy.query_mode = '50%'
    #
    def query_mode value
      chain { criteria.update_options query_mode: value }
    end

    # Sets query compilation mode for search request.
    # Not used if only one filter for search is specified.
    # Possible values:
    #
    # * <tt>:and</tt>
    #   Default value. Filter compiles into an <tt>and</tt> filter.
    #
    #   Ex:
    #
    #     UsersIndex.filter{ name == 'Johny' }.filter{ age <= 42 }
    #       # => {body: {query: {filtered: {
    #              query: {...},
    #              filter: {and: [{term: {name: 'Johny'}}, {range: {age: {lte: 42}}}]}
    #            }}}}
    #
    # * <tt>:or</tt>
    #   Filter compiles into an <tt>or</tt> filter.
    #
    #   Ex:
    #
    #     UsersIndex.filter{ name == 'Johny' }.filter{ age <= 42 }.filter_mode(:or)
    #       # => {body: {query: {filtered: {
    #              query: {...},
    #              filter: {or: [{term: {name: 'Johny'}}, {range: {age: {lte: 42}}}]}
    #            }}}}
    #
    # * <tt>:must</tt>
    #   Filter compiles into a bool <tt>must</tt> filter.
    #
    #   Ex:
    #
    #     UsersIndex.filter{ name == 'Johny' }.filter{ age <= 42 }.filter_mode(:must)
    #       # => {body: {query: {filtered: {
    #              query: {...},
    #              filter: {bool: {must: [{term: {name: 'Johny'}}, {range: {age: {lte: 42}}}]}}
    #            }}}}
    #
    # * <tt>:should</tt>
    #   Filter compiles into a bool <tt>should</tt> filter.
    #
    #   Ex:
    #
    #     UsersIndex.filter{ name == 'Johny' }.filter{ age <= 42 }.filter_mode(:should)
    #       # => {body: {query: {filtered: {
    #              query: {...},
    #              filter: {bool: {should: [{term: {name: 'Johny'}}, {range: {age: {lte: 42}}}]}}
    #            }}}}
    #
    # * Any acceptable <tt>minimum_should_match</tt> value (1, '2', '75%')
    #   Filter compiles into bool <tt>should</tt> filter with <tt>minimum_should_match</tt> set.
    #
    #   Ex:
    #
    #     UsersIndex.filter{ name == 'Johny' }.filter{ age <= 42 }.filter_mode('50%')
    #       # => {body: {query: {filtered: {
    #              query: {...},
    #              filter: {bool: {
    #                should: [{term: {name: 'Johny'}}, {range: {age: {lte: 42}}}],
    #                minimum_should_match: '50%'
    #              }}
    #            }}}}
    #
    # Default value for <tt>:filter_mode</tt> might be changed
    # with <tt>Chewy.filter_mode</tt> config option.
    #
    #   Chewy.filter_mode = :should
    #   Chewy.filter_mode = '50%'
    #
    def filter_mode value
      chain { criteria.update_options filter_mode: value }
    end

    # Acts the same way as `filter_mode`, but used for `post_filter`.
    # Note that it fallbacks by default to `Chewy.filter_mode` if
    # `Chewy.post_filter_mode` is nil.
    #
    #   UsersIndex.post_filter{ name == 'Johny' }.post_filter{ age <= 42 }.post_filter_mode(:and)
    #   UsersIndex.post_filter{ name == 'Johny' }.post_filter{ age <= 42 }.post_filter_mode(:should)
    #   UsersIndex.post_filter{ name == 'Johny' }.post_filter{ age <= 42 }.post_filter_mode('50%')
    #
    def post_filter_mode value
      chain { criteria.update_options post_filter_mode: value }
    end

    # Sets elasticsearch <tt>size</tt> search request param
    # Default value is set in the elasticsearch and is 10.
    #
    #  UsersIndex.filter{ name == 'Johny' }.limit(100)
    #     # => {body: {
    #            query: {...},
    #            size: 100
    #          }}
    #
    def limit value
      chain { criteria.update_request_options size: Integer(value) }
    end

    # Sets elasticsearch <tt>from</tt> search request param
    #
    #  UsersIndex.filter{ name == 'Johny' }.offset(300)
    #     # => {body: {
    #            query: {...},
    #            from: 300
    #          }}
    #
    def offset value
      chain { criteria.update_request_options from: Integer(value) }
    end

    # Elasticsearch highlight query option support
    #
    #   UsersIndex.query(...).highlight(fields: { ... })
    #
    def highlight value
      chain { criteria.update_request_options highlight: value }
    end

    # Elasticsearch rescore query option support
    #
    #   UsersIndex.query(...).rescore(query: { ... })
    #
    def rescore value
      chain { criteria.update_request_options rescore: value }
    end

    # Adds facets section to the search request.
    # All the chained facets a merged and added to the
    # search request
    #
    #   UsersIndex.facets(tags: {terms: {field: 'tags'}}).facets(ages: {terms: {field: 'age'}})
    #     # => {body: {
    #            query: {...},
    #            facets: {tags: {terms: {field: 'tags'}}, ages: {terms: {field: 'age'}}}
    #          }}
    #
    # If called parameterless - returns result facets from ES performing request.
    # Returns empty hash if no facets was requested or resulted.
    #
    def facets params = nil
      if params
        chain { criteria.update_facets params }
      else
        _response['facets'] || {}
      end
    end

    # Sets elasticsearch <tt>aggregations</tt> search request param
    #
    #  UsersIndex.filter{ name == 'Johny' }.aggregations(category_id: {terms: {field: 'category_ids'}})
    #     # => {body: {
    #            query: {...},
    #            aggregations: {
    #              terms: {
    #                field: 'category_ids'
    #              }
    #            }
    #          }}
    #
    def aggregations params = nil
      if params
        chain { criteria.update_aggregations params }
      else
        _response['aggregations'] || {}
      end
    end
    alias :aggs :aggregations

    # Marks the criteria as having zero records. This scope  always returns empty array
    # without touching the elasticsearch server.
    # All the chained calls of methods don't affect the result
    #
    #   UsersIndex.none.to_a
    #     # => []
    #   UsersIndex.query(text: {name: 'Johny'}).none.to_a
    #     # => []
    #   UsersIndex.none.query(text: {name: 'Johny'}).to_a
    #     # => []
    def none
      chain { criteria.update_options none: true }
    end

    # Setups strategy for top-level filtered query
    #
    #    UsersIndex.filter { name == 'Johny'}.strategy(:leap_frog)
    #     # => {body: {
    #            query: { filtered: {
    #              filter: { term: { name: 'Johny' } },
    #              strategy: 'leap_frog'
    #            } }
    #          }}
    #
    def strategy value = nil
      chain { criteria.update_options strategy: value }
    end

    # Adds one or more query to the search request
    # Internally queries are stored as an array
    # While the full query compilation this array compiles
    # according to <tt>:query_mode</tt> option value
    #
    # By default it joines inside <tt>must</tt> query
    # See <tt>#query_mode</tt> chainable method for more info.
    #
    #   UsersIndex.query(text: {name: 'Johny'}).query(range: {age: {lte: 42}})
    #   UsersIndex::User.query(text: {name: 'Johny'}).query(range: {age: {lte: 42}})
    #     # => {body: {
    #            query: {bool: {must: [{text: {name: 'Johny'}}, {range: {age: {lte: 42}}}]}}
    #          }}
    #
    # If only one query was specified, it will become a result
    # query as is, without joining.
    #
    #   UsersIndex.query(text: {name: 'Johny'})
    #     # => {body: {
    #            query: {text: {name: 'Johny'}}
    #          }}
    #
    def query params
      chain { criteria.update_queries params }
    end

    # Adds one or more filter to the search request
    # Internally filters are stored as an array
    # While the full query compilation this array compiles
    # according to <tt>:filter_mode</tt> option value
    #
    # By default it joins inside <tt>and</tt> filter
    # See <tt>#filter_mode</tt> chainable method for more info.
    #
    # Also this method supports block DSL.
    # See <tt>Chewy::Query::Filters</tt> for more info.
    #
    #   UsersIndex.filter(term: {name: 'Johny'}).filter(range: {age: {lte: 42}})
    #   UsersIndex::User.filter(term: {name: 'Johny'}).filter(range: {age: {lte: 42}})
    #   UsersIndex.filter{ name == 'Johny' }.filter{ age <= 42 }
    #     # => {body: {query: {filtered: {
    #            query: {...},
    #            filter: {and: [{term: {name: 'Johny'}}, {range: {age: {lte: 42}}}]}
    #          }}}}
    #
    # If only one filter was specified, it will become a result
    # filter as is, without joining.
    #
    #   UsersIndex.filter(term: {name: 'Johny'})
    #     # => {body: {query: {filtered: {
    #            query: {...},
    #            filter: {term: {name: 'Johny'}}
    #          }}}}
    #
    def filter params = nil, &block
      params = Filters.new(&block).__render__ if block
      chain { criteria.update_filters params }
    end

    # Adds one or more post_filter to the search request
    # Internally post_filters are stored as an array
    # While the full query compilation this array compiles
    # according to <tt>:post_filter_mode</tt> option value
    #
    # By default it joins inside <tt>and</tt> filter
    # See <tt>#post_filter_mode</tt> chainable method for more info.
    #
    # Also this method supports block DSL.
    # See <tt>Chewy::Query::Filters</tt> for more info.
    #
    #   UsersIndex.post_filter(term: {name: 'Johny'}).post_filter(range: {age: {lte: 42}})
    #   UsersIndex::User.post_filter(term: {name: 'Johny'}).post_filter(range: {age: {lte: 42}})
    #   UsersIndex.post_filter{ name == 'Johny' }.post_filter{ age <= 42 }
    #     # => {body: {
    #            post_filter: {and: [{term: {name: 'Johny'}}, {range: {age: {lte: 42}}}]}
    #          }}
    #
    # If only one post_filter was specified, it will become a result
    # post_filter as is, without joining.
    #
    #   UsersIndex.post_filter(term: {name: 'Johny'})
    #     # => {body: {
    #            post_filter: {term: {name: 'Johny'}}
    #          }}
    #
    def post_filter params = nil, &block
      params = Filters.new(&block).__render__ if block
      chain { criteria.update_post_filters params }
    end

    # Sets search request sorting
    #
    #   UsersIndex.order(:first_name, :last_name).order(age: :desc).order(price: {order: :asc, mode: :avg})
    #     # => {body: {
    #            query: {...},
    #            sort: ['first_name', 'last_name', {age: 'desc'}, {price: {order: 'asc', mode: 'avg'}}]
    #          }}
    #
    def order *params
      chain { criteria.update_sort params }
    end

    # Cleans up previous search sorting and sets the new one
    #
    #   UsersIndex.order(:first_name, :last_name).order(age: :desc).reorder(price: {order: :asc, mode: :avg})
    #     # => {body: {
    #            query: {...},
    #            sort: [{price: {order: 'asc', mode: 'avg'}}]
    #          }}
    #
    def reorder *params
      chain { criteria.update_sort params, purge: true }
    end

    # Sets search request field list
    #
    #   UsersIndex.only(:first_name, :last_name).only(:age)
    #     # => {body: {
    #            query: {...},
    #            fields: ['first_name', 'last_name', 'age']
    #          }}
    #
    def only *params
      chain { criteria.update_fields params }
    end

    # Cleans up previous search field list and sets the new one
    #
    #   UsersIndex.only(:first_name, :last_name).only!(:age)
    #     # => {body: {
    #            query: {...},
    #            fields: ['age']
    #          }}
    #
    def only! *params
      chain { criteria.update_fields params, purge: true }
    end

    # Specify types participating in the search result
    # Works via <tt>types</tt> filter. Always merged with another filters
    # with the <tt>and</tt> filter.
    #
    #   UsersIndex.types(:admin, :manager).filters{ name == 'Johny' }.filters{ age <= 42 }
    #     # => {body: {query: {filtered: {
    #            query: {...},
    #            filter: {and: [
    #              {or: [
    #                {type: {value: 'admin'}},
    #                {type: {value: 'manager'}}
    #              ]},
    #              {term: {name: 'Johny'}},
    #              {range: {age: {lte: 42}}}
    #            ]}
    #          }}}}
    #
    #   UsersIndex.types(:admin, :manager).filters{ name == 'Johny' }.filters{ age <= 42 }.filter_mode(:or)
    #     # => {body: {query: {filtered: {
    #            query: {...},
    #            filter: {and: [
    #              {or: [
    #                {type: {value: 'admin'}},
    #                {type: {value: 'manager'}}
    #              ]},
    #              {or: [
    #                {term: {name: 'Johny'}},
    #                {range: {age: {lte: 42}}}
    #              ]}
    #            ]}
    #          }}}}
    #
    def types *params
      if params.any?
        chain { criteria.update_types params }
      else
        @types
      end
    end

    # Acts the same way as <tt>types</tt>, but cleans up previously set types
    #
    #   UsersIndex.types(:admin).types!(:manager)
    #     # => {body: {query: {filtered: {
    #            query: {...},
    #            filter: {type: {value: 'manager'}}
    #          }}}}
    #
    def types! *params
      chain { criteria.update_types params, purge: true }
    end

    # Merges two queries.
    # Merges all the values in criteria with the same rules as values added manually.
    #
    #   scope1 = UsersIndex.filter{ name == 'Johny' }
    #   scope2 = UsersIndex.filter{ age <= 42 }
    #   scope3 = UsersIndex.filter{ name == 'Johny' }.filter{ age <= 42 }
    #
    #   scope1.merge(scope2) == scope3 # => true
    #
    def merge other
      chain { criteria.merge!(other.criteria) }
    end

  protected

    def initialize_clone other
      @criteria = other.criteria.clone
      reset
    end

  private

    def chain &block
      clone.tap { |q| q.instance_eval(&block) }
    end

    def reset
      @_request, @_response, @_results = nil
    end

    def _request
      @_request ||= criteria.request_body.merge(index: index.index_name, type: types)
    end

    def _response
      @_response ||= begin
        ActiveSupport::Notifications.instrument 'search_query.chewy', request: _request, index: index do
          begin
            index.client.search(_request)
          rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
            raise e if e.message !~ /IndexMissingException/
            {}
          end
        end
      end
    end

    MERGER = lambda do |key, old_value, new_value|
      if old_value.is_a?(Hash) && new_value.is_a?(Hash)
        old_value.merge(new_value, &MERGER)
      elsif new_value.is_a?(Array) && new_value.count > 1
        new_value
      else
        old_value.is_a?(Array) ? new_value : new_value.first
      end
    end

    def _results
      @_results ||= (criteria.none? || _response == {} ? [] : _response['hits']['hits']).map do |hit|
        attributes = (hit['_source'] || {}).merge(hit['highlight'] || {}, &MERGER)
        attributes.reverse_merge!(id: hit['_id']).merge!(_score: hit['_score'])

        wrapper = index.type_hash[hit['_type']].new attributes
        wrapper._data = hit
        wrapper
      end
    end
  end
end

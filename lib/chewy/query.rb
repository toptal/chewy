require 'chewy/query/criteria'
require 'chewy/query/filters'
require 'chewy/query/scoping'
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
    include Scoping
    include Loading
    include Pagination

    delegate :each, :count, :size, to: :_collection
    alias_method :to_ary, :to_a

    attr_reader :_indexes, :_types, :options, :criteria

    def initialize *indexes_or_types_and_options
      @options = indexes_or_types_and_options.extract_options!
      @_types = indexes_or_types_and_options.select { |klass| klass < Chewy::Type }
      @_indexes = indexes_or_types_and_options.select { |klass| klass < Chewy::Index }
      @_indexes |= @_types.map(&:index)
      @criteria = Criteria.new
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

    # Adds <tt>script_fields</tt> parameter to search request.
    #  UsersIndex.script_fields(
    #    distance: {
    #      params: {
    #        lat: 37.569976,
    #        lon: -122.351591
    #      },
    #      script: "doc['coordinates'].distanceInMiles(lat, lon)"
    #    }
    #  )
    def script_fields value
      chain { criteria.update_script_fields(value) }
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

    # A search timeout, bounding the search request to be executed within the
    # specified time value and bail with the hits accumulated up to that point
    # when expired. Defaults to no timeout.
    #
    # By default, the coordinating node waits to receive a response from all
    # shards. If one node is having trouble, it could slow down the response to
    # all search requests.
    #
    # The timeout parameter tells the coordinating node how long it should wait
    # before giving up and just returning the results that it already has. It
    # can be better to return some results than none at all.
    #
    # The response to a search request will indicate whether the search timed
    # out and how many shards responded successfully:
    #
    #   ...
    #   "timed_out":     true,
    #   "_shards": {
    #       "total":      5,
    #       "successful": 4,
    #       "failed":     1
    #   },
    #   ...
    #
    # The primary shard assigned to perform the index operation might not be
    # available when the index operation is executed. Some reasons for this
    # might be that the primary shard is currently recovering from a gateway or
    # undergoing relocation. By default, the index operation will wait on the
    # primary shard to become available for up to 1 minute before failing and
    # responding with an error. The timeout parameter can be used to explicitly
    # specify how long it waits.
    #
    #   UsersIndex.timeout("5000ms")
    #
    # Timeout is not a circuit breaker.
    #
    # It should be noted that this timeout does not halt the execution of the
    # query, it merely tells the coordinating node to return the results
    # collected so far and to close the connection. In the background, other
    # shards may still be processing the query even though results have been
    # sent.
    #
    # Use the timeout because it is important to your SLA, not because you want
    # to abort the execution of long running queries.
    #
    def timeout value
      chain { criteria.update_request_options timeout: value }
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

    # Elasticsearch minscore option support
    #
    # UsersIndex.query(...).min_score(0.5)
    #
    def min_score value
      chain { criteria.update_request_options min_score: value }
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
      raise RemovedFeature, 'removed in elasticsearch 2.0' if Runtime.version >= '2.0'
      if params
        chain { criteria.update_facets params }
      else
        _response['facets'] || {}
      end
    end

    # Adds a script function to score the search request. All scores are
    # added to the search request and combinded according to
    # <tt>boost_mode</tt> and <tt>score_mode</tt>
    #
    #   UsersIndex.script_score("doc['boost'].value", params: { modifier: 2 })
    #       # => {body:
    #              query: {
    #                function_score: {
    #                  query: { ...},
    #                  functions: [{
    #                    script_score: {
    #                       script: "doc['boost'].value * modifier",
    #                       params: { modifier: 2 }
    #                     }
    #                    }
    #                  }]
    #                } } }
    def script_score(script, options = {})
      scoring = { script_score: { script: script }.merge(options) }
      chain { criteria.update_scores scoring }
    end

    # Adds a boost factor to the search request. All scores are
    # added to the search request and combinded according to
    # <tt>boost_mode</tt> and <tt>score_mode</tt>
    #
    # This probably only makes sense if you specify a filter
    # for the boost factor as well
    #
    #   UsersIndex.boost_factor(23, filter: { term: { foo: :bar} })
    #       # => {body:
    #              query: {
    #                function_score: {
    #                  query: { ...},
    #                  functions: [{
    #                    boost_factor: 23,
    #                    filter: { term: { foo: :bar } }
    #                  }]
    #                } } }
    def boost_factor(factor, options = {})
      scoring = options.merge(boost_factor: factor.to_i)
      chain { criteria.update_scores scoring }
    end

    # Adds a random score to the search request. All scores are
    # added to the search request and combinded according to
    # <tt>boost_mode</tt> and <tt>score_mode</tt>
    #
    # This probably only makes sense if you specify a filter
    # for the random score as well.
    #
    # If you do not pass in a seed value, Time.now will be used
    #
    #   UsersIndex.random_score(23, filter: { foo: :bar})
    #       # => {body:
    #              query: {
    #                function_score: {
    #                  query: { ...},
    #                  functions: [{
    #                    random_score: { seed: 23 },
    #                    filter: { foo: :bar }
    #                  }]
    #                } } }
    def random_score(seed = Time.now, options = {})
      scoring = options.merge(random_score: { seed: seed.to_i })
      chain { criteria.update_scores scoring }
    end

    # Add a field value scoring to the search. All scores are
    # added to the search request and combinded according to
    # <tt>boost_mode</tt> and <tt>score_mode</tt>
    #
    # This function is only available in Elasticsearch 1.2 and
    # greater
    #
    #   UsersIndex.field_value_factor(
    #                {
    #                  field: :boost,
    #                  factor: 1.2,
    #                  modifier: :sqrt
    #                }, filter: { foo: :bar})
    #       # => {body:
    #              query: {
    #                function_score: {
    #                  query: { ...},
    #                  functions: [{
    #                    field_value_factor: {
    #                      field: :boost,
    #                      factor: 1.2,
    #                      modifier: :sqrt
    #                    },
    #                    filter: { foo: :bar }
    #                  }]
    #                } } }
    def field_value_factor(settings, options = {})
      scoring = options.merge(field_value_factor: settings)
      chain { criteria.update_scores scoring }
    end

    # Add a decay scoring to the search. All scores are
    # added to the search request and combinded according to
    # <tt>boost_mode</tt> and <tt>score_mode</tt>
    #
    # The parameters have default values, but those may not
    # be very useful for most applications.
    #
    #   UsersIndex.decay(
    #                :gauss,
    #                :field,
    #                origin: '11, 12',
    #                scale: '2km',
    #                offset: '5km',
    #                decay: 0.4,
    #                filter: { foo: :bar})
    #       # => {body:
    #              query: {
    #                gauss: {
    #                  query: { ...},
    #                  functions: [{
    #                    gauss: {
    #                      field: {
    #                        origin: '11, 12',
    #                        scale: '2km',
    #                        offset: '5km',
    #                        decay: 0.4
    #                      }
    #                    },
    #                    filter: { foo: :bar }
    #                  }]
    #                } } }
    def decay(function, field, options = {})
      field_options = options.extract!(:origin, :scale, :offset, :decay).delete_if { |_, v| v.nil? }
      scoring = options.merge(function => {
        field => field_options
      })
      chain { criteria.update_scores scoring }
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
      @_named_aggs ||= _build_named_aggs
      @_fully_qualified_named_aggs ||= _build_fqn_aggs
      if params
        params = { params => @_named_aggs[params] } if params.is_a?(Symbol)
        params = { params => _get_fully_qualified_named_agg(params) } if params.is_a?(String) && params =~ /\A\S+#\S+\.\S+\z/
        chain { criteria.update_aggregations params }
      else
        _response['aggregations'] || {}
      end
    end
    alias :aggs :aggregations

    # In this simplest of implementations each named aggregation must be uniquely named
    def _build_named_aggs
      named_aggs = {}
      @_indexes.each do |index|
        index.types.each do |type|
          type._agg_defs.each do |agg_name, prc|
            named_aggs[agg_name] = prc.call
          end
        end
      end
      named_aggs
    end

    def _build_fqn_aggs
      named_aggs = {}
      @_indexes.each do |index|
        named_aggs[index.to_s.downcase] ||= {}
        index.types.each do |type|
          named_aggs[index.to_s.downcase][type.to_s.downcase] ||= {}
          type._agg_defs.each do |agg_name, prc|
            named_aggs[index.to_s.downcase][type.to_s.downcase][agg_name.to_s.downcase] = prc.call
          end
        end
      end
      named_aggs
    end

    def _get_fully_qualified_named_agg(str)
      parts = str.scan(/\A(\S+)#(\S+)\.(\S+)\z/).first
      idx = "#{parts[0]}index"
      type = "#{idx}::#{parts[1]}"
      agg_name = parts[2]
      @_fully_qualified_named_aggs[idx][type][agg_name]
    end

    # Sets elasticsearch <tt>suggest</tt> search request param
    #
    #  UsersIndex.suggest(name: {text: 'Joh', term: {field: 'name'}})
    #     # => {body: {
    #            query: {...},
    #            suggest: {
    #              text: 'Joh',
    #              term: {
    #                field: 'name'
    #              }
    #            }
    #          }}
    #
    def suggest params = nil
      if params
        chain { criteria.update_suggest params }
      else
        _response['suggest'] || {}
      end
    end

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
    #
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

    # Sets the boost mode for custom scoring/boosting.
    # Not used if no score functions are specified
    # Possible values:
    #
    # * <tt>:multiply</tt>
    #   Default value. Query score and function result are multiplied.
    #
    #   Ex:
    #
    #     UsersIndex.boost_mode('multiply').script_score('doc['boost'].value')
    #       # => {body: {query: function_score: {
    #         query: {...},
    #         boost_mode: 'multiply',
    #         functions: [ ... ]
    #       }}}
    #
    # * <tt>:replace</tt>
    #   Only function result is used, query score is ignored.
    #
    # * <tt>:sum</tt>
    #   Query score and function score are added.
    #
    # * <tt>:avg</tt>
    #   Average of query and function score.
    #
    # * <tt>:max</tt>
    #   Max of query and function score.
    #
    # * <tt>:min</tt>
    #   Min of query and function score.
    #
    # Default value for <tt>:boost_mode</tt> might be changed
    # with <tt>Chewy.score_mode</tt> config option.
    def boost_mode value
      chain { criteria.update_options boost_mode: value }
    end

    # Sets the scoring mode for combining function scores/boosts
    # Not used if no score functions are specified.
    # Possible values:
    #
    # * <tt>:multiply</tt>
    #   Default value. Scores are multiplied.
    #
    #   Ex:
    #
    #     UsersIndex.score_mode('multiply').script_score('doc['boost'].value')
    #       # => {body: {query: function_score: {
    #         query: {...},
    #         score_mode: 'multiply',
    #         functions: [ ... ]
    #       }}}
    #
    # * <tt>:sum</tt>
    #   Scores are summed.
    #
    # * <tt>:avg</tt>
    #   Scores are averaged.
    #
    # * <tt>:first</tt>
    #   The first function that has a matching filter is applied.
    #
    # * <tt>:max</tt>
    #   Maximum score is used.
    #
    # * <tt>:min</tt>
    #   Minimum score is used
    #
    # Default value for <tt>:score_mode</tt> might be changed
    # with <tt>Chewy.score_mode</tt> config option.
    #
    #   Chewy.score_mode = :first
    #
    def score_mode value
      chain { criteria.update_options score_mode: value }
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
      chain { criteria.update_types params }
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

    # Sets <tt>search_type</tt> for request.
    # For instance, one can use <tt>search_type=count</tt> to fetch only total count of records or to fetch only aggregations without fetching records.
    #
    #   scope = UsersIndex.search_type(:count)
    #   scope.count == 0  # no records actually fetched
    #   scope.total == 10 # but we know a total count of them
    #
    #   scope = UsersIndex.aggs(max_age: { max: { field: 'age' } }).search_type(:count)
    #   max_age = scope.aggs['max_age']['value']
    #
    def search_type val
      chain { options.merge!(search_type: val) }
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

    # Deletes all records matching a query.
    #
    #   UsersIndex.delete_all
    #   UsersIndex.filter{ age <= 42 }.delete_all
    #   UsersIndex::User.delete_all
    #   UsersIndex::User.filter{ age <= 42 }.delete_all
    #
    def delete_all
      if Runtime.version > '2.0'
        plugins = Chewy.client.nodes.info(plugins: true)["nodes"].values.map { |item| item["plugins"] }.flatten
        raise PluginMissing, "install delete-by-query plugin" unless plugins.find { |item| item["name"] == 'delete-by-query' }
      end
      request = chain { criteria.update_options simple: true }.send(:_request)
      ActiveSupport::Notifications.instrument 'delete_query.chewy',
        request: request, indexes: _indexes, types: _types,
        index: _indexes.one? ? _indexes.first : _indexes,
        type: _types.one? ? _types.first : _types do
          Chewy.client.delete_by_query(request)
      end
    end

    # Find all records matching a query.
    #
    #   UsersIndex.find(42)
    #   UsersIndex.filter{ age <= 42 }.find(42)
    #   UsersIndex::User.find(42)
    #   UsersIndex::User.filter{ age <= 42 }.find(42)
    #
    # In all the previous examples find will return a single object.
    # To get a collection - pass an array of ids.
    #
    #    UsersIndex::User.find(42, 7, 3) # array of objects with ids in [42, 7, 3]
    #    UsersIndex::User.find([8, 13])  # array of objects with ids in [8, 13]
    #    UsersIndex::User.find([42])     # array of the object with id == 42
    #
    def find *ids
      results = chain { criteria.update_options simple: true }.filter { _id == ids.flatten }.to_a

      raise Chewy::DocumentNotFound.new("Could not find documents for ids #{ids.flatten}") if results.empty?
      ids.one? && !ids.first.is_a?(Array) ? results.first : results
    end

    # Returns request total time elapsed as reported by elasticsearch
    #
    #   UsersIndex.query(...).filter(...).took
    #
    def took
      _response['took']
    end

    # Returns request timed_out as reported by elasticsearch
    #
    # The timed_out value tells us whether the query timed out or not.
    #
    # By default, search requests do not timeout. If low response times are more
    # important to you than complete results, you can specify a timeout as 10 or
    # "10ms" (10 milliseconds), or "1s" (1 second). See #timeout method.
    #
    #   UsersIndex.query(...).filter(...).timed_out
    #
    def timed_out
      _response['timed_out']
    end

  protected

    def initialize_clone other
      @criteria = other.criteria.clone
      reset
    end

  private

    def chain &block
      clone.tap { |q| q.instance_exec(&block) }
    end

    def reset
      @_request, @_response, @_results, @_collection = nil
    end

    def _request
      @_request ||= begin
        request = criteria.request_body
        request.merge!(index: _indexes.map(&:index_name), type: _types.map(&:type_name))
        request.merge!(search_type: options[:search_type]) if options[:search_type]
        request
      end
    end

    def _response
      @_response ||= ActiveSupport::Notifications.instrument 'search_query.chewy',
        request: _request, indexes: _indexes, types: _types,
        index: _indexes.one? ? _indexes.first : _indexes,
        type: _types.one? ? _types.first : _types do
          begin
            Chewy.client.search(_request)
          rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
            raise e if e.message !~ /IndexMissingException/ && e.message !~ /index_not_found_exception/
            {}
          end
      end
    end

    def _results
      @_results ||= (criteria.none? || _response == {} ? [] : _response['hits']['hits']).map do |hit|
        attributes = (hit['_source'] || {})
          .reverse_merge(id: hit['_id'])
          .merge!(_score: hit['_score'])
          .merge!(_explanation: hit['_explanation'])

        wrapper = _derive_index(hit['_index']).type(hit['_type']).new(attributes)
        wrapper._data = hit
        wrapper
      end
    end

    def _collection
      @_collection ||= begin
        _load_objects! if criteria.options[:preload]
        criteria.options[:preload] && criteria.options[:loaded_objects] ?
          _results.map(&:_object) : _results
      end
    end

    def _derive_index index_name
      (@derive_index ||= {})[index_name] ||= _indexes_hash[index_name] ||
        _indexes_hash[_indexes_hash.keys.sort_by(&:length).reverse.detect { |name| index_name.start_with?(name) }]
    end

    def _indexes_hash
      @_indexes_hash ||= _indexes.index_by(&:index_name)
    end
  end
end

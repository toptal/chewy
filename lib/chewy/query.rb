begin
  require 'kaminari'
rescue LoadError
end

require 'chewy/query/criteria'
require 'chewy/query/context'
require 'chewy/query/loading'
require 'chewy/query/pagination'

module Chewy
  class Query
    include Enumerable
    include Loading
    include Pagination

    DEFAULT_OPTIONS = {}

    delegate :each, :count, :size, to: :_results
    alias_method :to_ary, :to_a

    attr_reader :index, :options, :criteria

    def initialize(index, options = {})
      @index, @options = index, DEFAULT_OPTIONS.merge(options)
      @types = Array.wrap(options.delete(:types))
      @criteria = Criteria.new
      reset
    end

    def ==(other)
      if other.is_a?(self.class)
        other.criteria == criteria
      else
        to_a == other
      end
    end

    def explain(value = nil)
      chain { criteria.update_options explain: (value.nil? ? true : value) }
    end

    def limit(value)
      chain { criteria.update_options size: Integer(value) }
    end

    def offset(value)
      chain { criteria.update_options from: Integer(value) }
    end

    def facets(params)
      chain { criteria.update_facets params }
    end

    def query(params)
      chain { criteria.update_query params }
    end

    def filter(params = nil, &block)
      params = Context.new(&block).__render__ if block
      chain { criteria.update_filters params }
    end

    def order(*params)
      chain { criteria.update_sort params }
    end

    def reorder(*params)
      chain { criteria.update_sort params, purge: true }
    end

    def only(*params)
      chain { criteria.update_fields params }
    end

    def only!(*params)
      chain { criteria.update_fields params, purge: true }
    end

    def types(*params)
      if params.any?
        chain { criteria.update_types params }
      else
        @types
      end
    end

    def types!(*params)
      chain { criteria.update_types params, purge: true }
    end

    def merge other
      chain { criteria.merge!(other.criteria) }
    end

  protected

    def initialize_clone(other)
      @criteria = other.criteria.clone
      reset
    end

  private

    def chain &block
      clone.tap { |q| q.instance_eval(&block) }
    end

    def reset
      @_response, @_results = nil
    end

    def _filters
      filters = criteria.filters
      types = criteria.types

      if types.many?
        filters.push(or: types.map { |type| {type: {value: type}} })
      elsif types.one?
        filters.push(type: {value: types.first})
      end

      if filters.many?
        {and: filters}
      else
        filters.first
      end
    end

    def _request_query
      filters = _filters

      if filters
        {query: {
          filtered: {
            query: criteria.query? ? criteria.query : {match_all: {}},
            filter: filters
          }
        }}
      elsif criteria.query?
        {query: criteria.query}
      else
        {}
      end
    end

    def _request_body
      body = _request_query
      body = body.merge!(facets: criteria.facets) if criteria.facets?
      body = body.merge!(sort: criteria.sort) if criteria.sort?
      body = body.merge!(fields: criteria.fields) if criteria.fields?
      {body: body}
    end

    def _request_target
      {index: index.index_name, type: types}
    end

    def _request
      [criteria.options, _request_target, _request_body].inject(:merge)
    end

    def _response
      @_response ||= index.client.search(_request)
    end

    def _results
      @_results ||= _response['hits']['hits'].map do |hit|
        attributes = hit['_source'] || hit['fields'] || {}
        attributes.reverse_merge!(id: hit['_id']).merge!(_score: hit['_score'])
        attributes.merge!(_explain: hit['_explanation']) if hit['_explanation']
        index.type_hash[hit['_type']].new attributes
      end
    end
  end
end

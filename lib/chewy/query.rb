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
      chain { criteria.update_queries params }
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
      @_request, @_response, @_results = nil
    end

    def _request
      @_request ||= criteria.request_body.merge(index: index.index_name, type: types)
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

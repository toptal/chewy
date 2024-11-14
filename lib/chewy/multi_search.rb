# frozen_string_literal: true

module Chewy
  # `Chewy::MultiSearch` provides an interface for executing multiple
  # queries via the Elasticsearch Multi Search API. When a MultiSearch
  # is performed it wraps the responses from Elasticsearch and assigns
  # them to the appropriate queries.
  class MultiSearch
    attr_reader :queries

    # Instantiate a new MultiSearch instance.
    #
    # @param queries [Array<Chewy::Search::Request>]
    # @option [Elasticsearch::Transport::Client] :client (Chewy.client)
    #   The Elasticsearch client that should be used for issuing requests.
    def initialize(queries, client: Chewy.client)
      @client = client
      @queries = Array(queries)
    end

    # Adds a query to be performed by the MultiSearch
    #
    # @param query [Chewy::Search::Request]
    def add_query(query)
      @queries << query
    end

    # Performs any unperformed queries and returns the responses for all queries.
    #
    # @return [Array<Chewy::Search::Response>]
    def responses
      perform
      queries.map(&:response)
    end

    # Performs any unperformed queries.
    def perform
      unperformed_queries = queries.reject(&:performed?)
      return if unperformed_queries.empty?

      responses = msearch(unperformed_queries)['responses']
      unperformed_queries.zip(responses).map { |query, response| query.response = response }
    end

  private

    attr_reader :client

    def msearch(queries_to_search)
      body = queries_to_search.flat_map do |query|
        rendered = query.render
        [rendered.except(:body), rendered[:body]]
      end

      client(@hosts_name).msearch(body: body)
    end
  end

  def self.msearch(queries)
    Chewy::MultiSearch.new(queries)
  end
end

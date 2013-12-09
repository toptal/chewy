module Chewy
  class Query
    class Criteria
      STORAGES = [:search, :query, :facets, :filters, :sort, :fields]

      def ==(other)
        storages == other.storages
      end

      def storages
        STORAGES.map { |storage| send(storage) }
      end

      [:search, :query, :facets].each do |storage|
        class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def #{storage}
            @#{storage} ||= {}
          end
        METHODS
      end

      [:filters, :sort, :fields].each do |storage|
        class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def #{storage}
            @#{storage} ||= []
          end
        METHODS
      end

      STORAGES.each do |storage|
        class_eval <<-METHODS, __FILE__, __LINE__ + 1
          def #{storage}?
            #{storage}.any?
          end
        METHODS
      end

      def update_search(modifer)
        search.merge!(modifer)
      end

      def update_query(modifer)
        query.merge!(modifer)
      end


      def update_facets(modifer)
        facets.merge!(modifer)
      end

      def update_filters(modifer)
        @filters = filters + Array.wrap(modifer).delete_if(&:blank?)
      end

      def update_sort(modifer, options = {})
        @sort = nil if options[:purge]
        modifer = Array.wrap(modifer).flatten.map do |element|
          element.is_a?(Hash) ? element.map { |k, v| {k => v} } : element
        end.flatten
        @sort = sort + modifer
      end

      def update_fields(modifer, options = {})
        @fields = nil if options[:purge]
        @fields = (fields + Array.wrap(modifer).flatten.map(&:to_s).delete_if(&:blank?)).uniq
      end

    protected

      def initialize_clone(other)
        STORAGES.each do |storage|
          value = other.send(storage)
          if value
            value = Marshal.load(Marshal.dump(value))
            instance_variable_set("@#{storage}", value)
          end
        end
      end
    end
  end
end

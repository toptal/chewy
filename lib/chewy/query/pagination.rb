module Chewy
  class Query
    module Pagination
      extend ActiveSupport::Concern

      included do
        include Kaminari if defined?(::Kaminari)
      end

      module Kaminari
        extend ActiveSupport::Concern

        included do
          include ::Kaminari::PageScopeMethods

          delegate :default_per_page, :max_per_page, :max_pages, to: :_kaminari_config

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            def #{::Kaminari.config.page_method_name}(num = 1)
              limit(limit_value).offset(limit_value * ([num.to_i, 1].max - 1))
            end
          RUBY
        end

        def total_count
          _response['hits']['total']
        end

        def limit_value
          (criteria.options[:size].presence || default_per_page).to_i
        end

        def offset_value
          criteria.options[:from].to_i
        end

      private

        def _kaminari_config
          ::Kaminari.config
        end
      end
    end
  end
end

module Chewy
  module Search
    module Pagination
      module Kaminari
        extend ActiveSupport::Concern

        included do
          include ::Kaminari::PageScopeMethods
          prepend PrependedMethods

          delegate :default_per_page, :max_per_page, :max_pages, to: :_kaminari_config

          class_eval <<-METHOD, __FILE__, __LINE__ + 1
            def #{::Kaminari.config.page_method_name}(num = 1)
              limit(limit_value).offset(limit_value * ([num.to_i, 1].max - 1))
            end
          METHOD
        end

        module PrependedMethods
        private

          def limit_value
            (super || default_per_page).to_i
          end

          def offset_value
            super.to_i
          end
        end

      private

        def _kaminari_config
          ::Kaminari.config
        end
      end
    end
  end
end

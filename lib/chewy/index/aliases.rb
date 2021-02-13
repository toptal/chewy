module Chewy
  class Index
    module Aliases
      extend ActiveSupport::Concern

      module ClassMethods
        def indexes
          get_args = {index: index_name}
          get_args[:include_type_name] = true if Runtime.version >= '6.7.0'
          indexes = empty_if_not_found { client.indices.get(**get_args).keys }
          indexes += empty_if_not_found { client.indices.get_alias(name: index_name).keys }
          indexes.compact.uniq
        end

        def aliases
          empty_if_not_found do
            client.indices.get_alias(index: index_name, name: '*').values.flat_map do |aliases|
              aliases['aliases'].keys
            end
          end.compact.uniq
        end

      private

        def empty_if_not_found
          yield
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          []
        end
      end
    end
  end
end

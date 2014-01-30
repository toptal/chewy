module Chewy
  class Index
    module Aliases
      extend ActiveSupport::Concern

      module ClassMethods
        def indexes
          client.indices.get_alias(name: index_name).keys
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          []
        end

        def aliases
          client.indices.get_alias(index: index_name, name: '*')[index_name].try(:[], 'aliases').try(:keys) || []
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          []
        end
      end
    end
  end
end

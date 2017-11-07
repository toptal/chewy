module Chewy
  class Index
    module Aliases
      extend ActiveSupport::Concern

      module ClassMethods
        def indexes
          client(@hosts_name).indices.get_alias(name: index_name).keys
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          []
        end

        def aliases
          name = index_name
          client(@hosts_name).indices.get_alias(index: name, name: '*')[name].try(:[], 'aliases').try(:keys) || []
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          []
        end
      end
    end
  end
end

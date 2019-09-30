module Chewy
  class Index
    module Aliases
      extend ActiveSupport::Concern

      module ClassMethods
        def indexes
          client.indices.get(index: "#{index_name}*").keys
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          []
        end

        def aliases
          client.indices.get(index: "#{index_name}*").values.flat_map {|i| i['aliases'].keys }
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          []
        end
      end
    end
  end
end

module Chewy
  class Index
    module Actions
      extend ActiveSupport::Concern

      module ClassMethods
        def index_exists?
          client.indices.exists(index: index_name)
        end

        def index_create
          index_create!
        rescue Elasticsearch::Transport::Transport::Errors::BadRequest
          false
        end

        def index_create!
          client.indices.create(index: index_name, body: index_params)
        end

        def index_delete
          index_delete!
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          false
        end

        def index_delete!
          client.indices.delete(index: index_name)
        end

        def index_purge
          index_delete
          index_create
        end

        def index_purge!
          index_delete
          index_create!
        end
      end
    end
  end
end

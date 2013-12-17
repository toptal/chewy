module Chewy
  class Index
    module Actions
      extend ActiveSupport::Concern

      module ClassMethods
        def exists?
          client.indices.exists(index: index_name)
        end

        def create
          create!
        rescue Elasticsearch::Transport::Transport::Errors::BadRequest
          false
        end

        def create!
          client.indices.create(index: index_name, body: index_params)
        end

        def delete
          delete!
        rescue Elasticsearch::Transport::Transport::Errors::NotFound
          false
        end

        def delete!
          client.indices.delete(index: index_name)
        end

        def purge
          delete
          create
        end

        def purge!
          delete
          create!
        end
      end
    end
  end
end

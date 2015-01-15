module Chewy
  class Worker

    include Sidekiq::Worker

    def perform(index_name, ids)
      index_name.import ids
    end
  end
end

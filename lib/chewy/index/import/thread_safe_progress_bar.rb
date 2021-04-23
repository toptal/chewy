module Chewy
  class Index
    module Import
      # This class performs the threading for parallel import to avoid concurrency during progressbar output.
      #
      # @see Chewy::Type::Import::ClassMethods#import with `parallel: true` option
      class ThreadSafeProgressBar
        def initialize(enabled)
          @enabled = enabled

          return unless @enabled

          @mutex = Mutex.new
          @released = false
          @progressbar = ProgressBar.create total: nil
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              @mutex.synchronize { @released = true }
              @progressbar.total = yield
            end
          end
        end

        def increment(value)
          return unless @enabled

          @mutex.synchronize do
            @progressbar.progress += value
          end
        end

        def wait_until_ready
          return true unless @enabled

          @mutex.synchronize { @released } until @released
        end
      end
    end
  end
end

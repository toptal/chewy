module Chewy
  class Index
    module Import
      # Thin wrapper around `ruby-progressbar` for import feedback.
      #
      # Unlike the original PR #787 implementation, this wrapper is only
      # touched from the parent process: serial imports increment it directly,
      # and parallel imports increment it via `Parallel`'s `finish:` callback
      # (which runs in the parent under an internal mutex). The workers stay
      # process-based, so there is no GVL contention as in PR #787 / #800.
      #
      # `Progressbar.build` returns a NULL object when the feature is disabled,
      # so call sites do not need feature guards.
      class Progressbar
        NULL = Object.new
        class << NULL
          def increment(_); end
          def total=(_); end
          def finish; end
        end

        BOUNDED_FORMAT = '%t |%B| %p%% %c/%C %e'.freeze
        UNBOUNDED_FORMAT = '%t %c (%a)'.freeze
        TITLE = 'Importing'.freeze

        # @param enabled [Boolean, :unbounded] feature flag. `:unbounded` shows
        #   a spinner with no total (skip `import_count`).
        # @param total [Integer, nil] expected total; ignored when `:unbounded`.
        # @return [Progressbar, NULL]
        def self.build(enabled, total)
          return NULL unless enabled

          unless '::ProgressBar'.safe_constantize
            raise 'The `ruby-progressbar` gem is required for import progress, ' \
                  "please add `gem 'ruby-progressbar'` to your Gemfile"
          end

          return new if enabled == :unbounded

          new(normalize_total(total))
        end

        # Some ActiveRecord scopes (e.g., `.group(...)`) make `.count` return a
        # Hash rather than an Integer. Coerce so we still get a usable total.
        def self.normalize_total(total)
          case total
          when Hash then total.values.sum
          when Integer then total
          end
        end

        attr_reader :bar

        def initialize(total = nil)
          format = total ? BOUNDED_FORMAT : UNBOUNDED_FORMAT
          @bar = ::ProgressBar.create(title: TITLE, total: total, format: format)
        end

        # Clamps to total when bounded — action_objects may include :delete
        # entries (parent-child re-indexing, delete_if scope) that aren't
        # counted by `adapter.import_count`, which would otherwise raise
        # ProgressBar::InvalidProgressError.
        def increment(by)
          target = bar.progress + by
          target = [bar.total, target].min if bar.total
          bar.progress = target
        end

        def total=(value)
          bar.total = value
        end

        def finish
          bar.finish unless bar.finished?
        end
      end
    end
  end
end

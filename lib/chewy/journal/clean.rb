module Chewy
  class Journal
    module Clean
      def until(time)
        Chewy::Stash::Journal
          .filter(range: {created_at: {lte: time.to_i}})
          .delete_all['deleted']
      end
      module_function :until
    end
  end
end

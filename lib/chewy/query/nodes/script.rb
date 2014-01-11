module Chewy
  class Query
    module Nodes
      class Script < Expr
        def initialize script, params = {}
          @script = script
          @params = params
        end

        def __render__
          script = {script: @script}
          script.merge!(params: @params) if @params.present?
          {script: script}
        end
      end
    end
  end
end

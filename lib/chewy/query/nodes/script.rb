module Chewy
  class Query
    module Nodes
      class Script < Expr
        def initialize script, params = {}
          @script = script
          @params = params
          @options = params.extract!(:cache)
        end

        def __render__
          script = {script: @script}
          script.merge!(params: @params) if @params.present?
          script.merge!(_cache: !!@options[:cache]) if @options.key?(:cache)
          {script: script}
        end
      end
    end
  end
end

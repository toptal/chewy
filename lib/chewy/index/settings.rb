module Chewy
  class Index

    # Stores ElasticSearch index settings and resolves `analysis`
    # hash. At first, you need to store sone analyzers or other
    # analysis options to the corresponding repository:
    #
    #   Chewy.analyzer :title_analyzer, type: 'custom', filter: %w(lowercase icu_folding title_nysiis)
    #   Chewy.filter :title_nysiis, type: 'phonetic', encoder: 'nysiis', replace: false
    #
    # `title_nysiis` filter here will be expanded automatically when
    # `title_analyzer` analyser will be used in index settings:
    #
    #   class ProductsIndex < Chewy::Index
    #     settings analysis: {
    #       analyzer: [
    #         'title_analyzer',
    #         {one_more_analyzer: {type: 'custom', tokenizer: 'lowercase'}}
    #       ]
    #     }
    #   end
    #
    # Additional analysing options, which wasn't stored in repositories,
    # might be used as well.
    #
    class Settings
      def initialize(params={})
        @params = params
      end

      def to_hash
        return {} unless @params.present?
        params = @params.deep_dup

        if analysis = resolve_analysis(params[:analysis])
          params[:analysis] = analysis
        end

        {settings: params}
      end

      def resolve_analysis(params)
        return unless params.is_a?(Hash)

        resolve(:analyzer, params, Chewy.analyzers)

        inject_dependencies(:tokenizer, params, Chewy.tokenizers)
        inject_dependencies(:filter, params, Chewy.filters)
        inject_dependencies(:char_filter, params, Chewy.char_filters)

        params
      end

      def inject_dependencies(type, params, repository)
        if collected = collect_dependencies(type, params)
          params[type] = collected
        end
        resolve(type, params, repository)
        params
      end

    private

      def collect_dependencies(type, analysis)
        return unless analysis[:analyzer]

        analysis[:analyzer].map do |name, options|
          options[type]
        end.compact.flatten + Array.wrap(analysis[type])
      end

      def resolve(type, params, repository)
        return unless params.is_a? Hash
        params.symbolize_keys!

        if params[type].is_a? Hash
          params[type]
        else
          if params[type]
            injected = params[type].inject({}) do |hash, name_or_hash|
              resolved = repository.resolve(name_or_hash)
              hash.update resolved ? resolved : {}
            end
            params[type] = injected
          end
        end

        params[type]
      end
    end
  end
end

class Chewy::Index::Settings
  def initialize(params={})
    @params = params
  end

  def to_hash
    return {} unless @params.present?
    params = @params.deep_dup
    params = roll_out_analysis(params)

    {settings: params}
  end

  def roll_out_analysis(params)
    return unless params.is_a?(Hash)

    roll_out(:analyzer, params, Chewy.analyzers)

    inject_dependencies(:tokenizer, params, Chewy.tokenizers)
    inject_dependencies(:filter, params, Chewy.filters)
    inject_dependencies(:char_filter, params, Chewy.char_filters)

    params
  end


  def inject_dependencies(type, params, repository)
    params[type] = collect_dependencies(type, params)
    roll_out(type, params, repository)
    params
  end

private

  def collect_dependencies(type, analysis)
    return unless analysis[:analyzer]

    analysis[:analyzer].map do |name, options|
      options[type]
    end.compact.flatten + Array.wrap(analysis[type])
  end

  def roll_out(type, params, repository)
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
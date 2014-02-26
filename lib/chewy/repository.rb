class Chewy::Repository
  def initialize(type_name, exclusions=[])
    @exclusions = exclusions
    @type_name  = type_name
    clear
  end

  def resolve(name, options=nil)
    if options.present?
      set(name, options)
    else
      get(name)
    end
  rescue Chewy::UndefinedAnalysisUnit => e
    raise e unless @exclusions.include?(e.item)
  end

  def set(name, options)
    @repository[name.to_sym] = options
    self
  end

  def get(name)
    if name.is_a? Hash
      name
    else
      {name.to_sym => @repository[name.to_sym]}
    end
  end

  def empty?
    @repository.empty?
  end

  def clear
    @repository = Hash.new { |hash, key| raise Chewy::UndefinedAnalysisUnit.new(@type_name, key) }
  end
end
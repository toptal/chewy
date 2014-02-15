class Chewy::Repository
  class UndefinedItem < Chewy::Error
    attr_reader :item, :type
    def initialize(type, item)
      @type, @item = type, item
      super "Undefined #{type}: #{item.inspect}"
    end
  end

  def initialize(type_name, exclusions=[])
    @exclusions = exclusions
    @type_name  = type_name
    @repository = Hash.new { |hash, key| raise Chewy::Repository::UndefinedItem.new(type_name, key) }
  end

  def resolve(name, options=nil)
    if options.present?
      set(name, options)
    else
      get(name)
    end
  rescue Chewy::Repository::UndefinedItem => e
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
end
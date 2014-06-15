class PaginatedArray < Array
  def initialize query, objects
    @query, @object = query, objects

    super(objects)
  end

  delegate :limit, :offset, :total_count, to: :@query
  delegate Kaminari.config.page_method_name.to_sym, to: :@query if defined?(::Kaminari)
end

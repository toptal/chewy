# Test helper class to provide minitest hooks for Chewy::Index testing.
#
# @note Intended to be used in conjunction with a test helper which mocks over the #bulk
#   method on a {Chewy::Index} class. (See {Chewy::Minitest::Helpers})
#
# The class will capture the data from the *param on the Chewy::Index.bulk method and
# aggregate the data for test analysis.
class SearchIndexReceiver
  MUTATION_FOR_CLASS = Struct.new(:indexes, :deletes, keyword_init: true)

  def initialize
    @mutations = {}
  end

  # @param bulk_params [Hash] the bulk_params that should be sent to the Chewy::Index.bulk method.
  # @param index [Chewy::Index] the index executing this query.
  def catch(bulk_params, index)
    Array.wrap(bulk_params).map { |y| y[:body] }.flatten.each do |update|
      if update[:delete]
        mutation_for(index).deletes << update[:delete][:_id]
      elsif update[:index]
        mutation_for(index).indexes << update[:index]
      end
    end
  end

  # @param index [Chewy::Index] return only index requests to the specified {Chewy::Index} index.
  # @return [Hash] the index changes captured by the mock.
  def indexes_for(index = nil)
    if index
      mutation_for(index).indexes
    else
      @mutations.transform_values(&:indexes)
    end
  end
  alias_method :indexes, :indexes_for

  # @param index [Chewy::Index] return only delete requests to the specified {Chewy::Index} index.
  # @return [Hash] the index deletes captured by the mock.
  def deletes_for(index = nil)
    if index
      mutation_for(index).deletes
    else
      @mutations.transform_values(&:deletes)
    end
  end
  alias_method :deletes, :deletes_for

  # Check to see if a given object has been indexed.
  # @param obj [#id] obj the object to look for.
  # @param index [Chewy::Index] what index the object should be indexed in.
  # @return [true, false] if the object was indexed.
  def indexed?(obj, index)
    indexes_for(index).map { |i| i[:_id] }.include? obj.id
  end

  # Check to see if a given object has been deleted.
  # @param obj [#id] obj the object to look for.
  # @param index [Chewy::Index] what index the object should have been deleted from.
  # @return [true, false] if the object was deleted.
  def deleted?(obj, index)
    deletes_for(index).include? obj.id
  end

  # @return [Array<Chewy::Index>] a list of indexes changed.
  def updated_indexes
    @mutations.keys
  end

private

  # Get the mutation object for a given index.
  # @param index [Chewy::Index] the index to fetch.
  # @return [#indexes, #deletes] an object with a list of indexes and a list of deletes.
  def mutation_for(index)
    @mutations[index] ||= MUTATION_FOR_CLASS.new(indexes: [], deletes: [])
  end
end

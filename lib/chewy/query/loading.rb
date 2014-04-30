module Chewy
  class Query
    module Loading
      extend ActiveSupport::Concern

      # Loads actual ORM/ODM objects for search result.
      # Returns array of ORM/ODM objects. In case when object
      # can not be loaded because it was deleted or don't satisfy
      # given scope or options - the result array will contain nil
      # value in the place of this object. Use `compact` method to
      # avoid this if necessary.
      #
      #   UsersIndex.query(...).load #=> [#<User id: 42...>, ...]
      #
      # Possible options:
      #
      #   <tt>:scope</tt> - used to give a scope for _every_ loaded type.
      #
      #       PlacesIndex.query(...).load(scope: ->{ includes(:testimonials) })
      #
      #     If places here contain cities and countries then preload will be
      #     done like this:
      #
      #       City.where(id: [...]).includes(:testimonials)
      #       Country.where(id: [...]).includes(:testimonials)
      #
      #     It is also possible to pass own scope for every loaded type:
      #
      #       PlacesIndex.query(...).load(
      #         city: { scope: ->{ includes(:testimonials, :country) }}
      #         country: { scope: ->{ includes(:testimonials, :cities) }}
      #       )
      #
      #     And loading will be performed as:
      #
      #       City.where(id: [...]).includes(:testimonials, :country)
      #       Country.where(id: [...]).includes(:testimonials, :cities)
      #
      #     In case of ActiveRecord objects loading the same result
      #     will be reached using ActiveRecord scopes instead of
      #     lambdas. But it works only with per-type scopes,
      #     and doesn't work with the common scope.
      #
      #       PlacesIndex.query(...).load(
      #         city: { scope: City.includes(:testimonials, :country) }
      #         country: { scope: Country.includes(:testimonials, :cities) }
      #       )
      #
      #   <tt>:only</tt> - loads objects for the specified types
      #
      #     PlacesIndex.query(...).load(only: :city)
      #     PlacesIndex.query(...).load(only: [:city])
      #     PlacesIndex.query(...).load(only: [:city, :country])
      #
      #   <tt>:except</tt> - doesn't load listed types
      #
      #     PlacesIndex.query(...).load(except: :city)
      #     PlacesIndex.query(...).load(except: [:city])
      #     PlacesIndex.query(...).load(except: [:city, :country])
      #
      #  Loaded objects are also attached to corresponding Chewy
      #  type wrapper objects and available with `_object` accessor.
      #
      #    scope = PlacesIndex.query(...)
      #    loaded_objects = scope.load
      #    scope.first #=> PlacesIndex::City wrapper instance
      #    scope.first._object #=> City model instance
      #    loaded_objects == scope.map(&:_object) #=> true
      #
      def load(options = {})
        if defined?(::Kaminari)
          ::Kaminari.paginate_array(_load_objects(options),
            limit: limit_value, offset: offset_value, total_count: total_count)
        else
          _load_objects(options)
        end
      end

      # This methods is just convenient way to preload some ORM/ODM
      # objects and continue to work with Chewy wrappers. Returns
      # Chewy query scope. Note that `load` method performs ES request
      # so preload method should also be the last in scope methods chain.
      # Takes the same options as the `load` method
      #
      #   PlacesIndex.query(...).preload(only: :city).map(&:_object)
      #
      def preload(options = {})
        tap { |scope| scope.load(options) }
      end

    private

      def _load_objects(options)
        only = Array.wrap(options[:only]).map(&:to_s)
        except = Array.wrap(options[:except]).map(&:to_s)

        loaded_objects = Hash[_results.group_by(&:class).map do |type, objects|
          next if except.include?(type.type_name)
          next if only.any? && !only.include?(type.type_name)

          loaded = type.adapter.load(objects, options.merge(_type: type))
          [type, loaded.index_by.with_index do |loaded, i|
            objects[i]._object = loaded
            objects[i]
          end]
        end.compact]

        _results.map do |result|
          loaded_objects[result.class][result] if loaded_objects[result.class]
        end
      end
    end
  end
end

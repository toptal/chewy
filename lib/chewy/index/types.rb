module Chewy
  class Index
    # Additional module extending index with type definition functionality.
    # In ES6 index types are deprecated.
    module Types
      extend ActiveSupport::Concern

      ADDITIONAL_METHODS = %i[type types type_names type_hash type_hash? type_hash=].freeze

      module AdditionalMethod
        extend ActiveSupport::Concern

        module ClassMethods
          # Types method has double usage.
          # If no arguments are passed - it returns array of defined types:
          #
          #   UsersIndex.types # => [UsersIndex::Admin, UsersIndex::Manager, UsersIndex::User]
          #
          # If arguments are passed it treats like a part of chainable query DSL and
          # adds types array for index to select.
          #
          #   UsersIndex.filters { name =~ 'ro' }.types(:admin, :manager)
          #   UsersIndex.types(:admin, :manager).filters { name =~ 'ro' } # the same as the first example
          #
          def types(*args)
            if args.present?
              all.types(*args)
            else
              type_hash.values
            end
          end

          # Returns defined types names:
          #
          #   UsersIndex.type_names # => ['admin', 'manager', 'user']
          #
          def type_names
            type_hash.keys
          end

          # Returns named type:
          #
          #    UserIndex.type('admin') # => UsersIndex::Admin
          #
          def type(type_name)
            type_hash.fetch(type_name) { raise UndefinedType, "Unknown type in #{name}: #{type_name}" }
          end
        end
      end

      module ClassMethods
        # Defines type for the index. Arguments depends on adapter used. For
        # ActiveRecord you can pass model or scope and options
        #
        #   class CarsIndex < Chewy::Index
        #     define_type Car do
        #       ...
        #     end # defines VehiclesIndex::Car type
        #   end
        #
        # Type name might be passed in complicated cases:
        #
        #   class VehiclesIndex < Chewy::Index
        #     define_type Vehicle.cars.includes(:manufacturer), name: 'cars' do
        #        ...
        #     end # defines VehiclesIndex::Cars type
        #
        #     define_type Vehicle.motocycles.includes(:manufacturer), name: 'motocycles' do
        #        ...
        #     end # defines VehiclesIndex::Motocycles type
        #   end
        #
        # For plain objects:
        #
        #   class PlanesIndex < Chewy::Index
        #     define_type :plane do
        #       ...
        #     end # defines PlanesIndex::Plane type
        #   end
        #
        # The main difference between using plain objects or ActiveRecord models for indexing
        # is import. If you will call `CarsIndex::Car.import` - it will import all the cars
        # automatically, while `PlanesIndex::Plane.import(my_planes)` requires import data to be
        # passed.
        #
        def define_type(target, options = {}, &block)
          extend_with_type_methods!
          type_class = Chewy.create_type(self, target, options, &block)
          self.type_hash = type_hash.merge(type_class.type_name => type_class)
        end

        # Checks whether index has defined at least 1 type.
        def has_types? # rubocop:disable Naming/PredicateName
          ancestors.include?(AdditionalMethod)
        end

      private

        def extend_with_type_methods!
          return if has_types?

          class_attribute :type_hash
          self.type_hash = {}

          include AdditionalMethod
        end
      end
    end
  end
end

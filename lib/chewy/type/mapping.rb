module Chewy
  module Type
    module Mapping
      extend ActiveSupport::Concern

      included do
        class_attribute :root_object, instance_reader: false, instance_writer: false
        class_attribute :_templates
      end

      module ClassMethods
        # Defines root object for mapping and is optional for type
        # definition. Use it only if you need to pass options for root
        # object mapping, such as `date_detection` or `dynamic_date_formats`
        #
        #   class UsersIndex < Chewy::Index
        #     define_type User do
        #       # root object defined implicitly and optionless for current type
        #       field :full_name, type: 'string'
        #     end
        #   end
        #
        #   class CarsIndex < Chewy::Index
        #     define_type Car do
        #       # explicit root definition with additional options
        #       root dynamic_date_formats: ['yyyy-MM-dd'] do
        #         field :model_name, type: 'string'
        #       end
        #     end
        #   end
        #
        def root options = {}, &block
          raise "Root is already defined" if root_object
          build_root(options, &block)
        end

        # Defines mapping field for current type
        #
        #   class UsersIndex < Chewy::Index
        #     define_type User do
        #       # passing all the options to field definition:
        #       field :full_name, type: 'string', analyzer: 'special'
        #     end
        #   end
        #
        # The `type` is optional and defaults to `string` if not defined:
        #
        #   field :full_name
        #
        # Also, multiple fields might be defined with one call and
        # with the same options:
        #
        #   field :first_name, :last_name, analyzer: 'special'
        #
        # The only special option in the field definition
        # is `:value`. If no `:value` specified then just corresponding
        # method will be called for the indexed object. Also
        # `:value` might be a proc or indexed object method name:
        #
        #   class User < ActiveRecord::Base
        #     def user_full_name
        #       [first_name, last_name].join(' ')
        #     end
        #   end
        #
        #   field :full_name, type: 'string', value: :user_full_name
        #
        # The proc evaluates inside the indexed object context if
        # its arity is 0 and in present contexts if there is an argument:
        #
        #   field :full_name, type: 'string', value: -> { [first_name, last_name].join(' ') }
        #
        #   separator = ' '
        #   field :full_name, type: 'string', value: ->(user) { [user.first_name, user.last_name].join(separator) }
        #
        # If array was returned as value - it will be put in index as well.
        #
        #   field :tags, type: 'string', value: -> { tags.map(&:name) }
        #
        # Fields supports nesting in case of `object` field type. If
        # `user.quiz` will return an array of objects, then result index content
        # will be an array of hashes, if `user.quiz` is not a collection association
        # then just values hash will be put in the index.
        #
        #   field :quiz, type: 'object' do
        #     field :question, :answer
        #     field :score, type: 'integer'
        #   end
        #
        # Nested fields are composed from nested objects:
        #
        #   field :name, type: 'object', value: -> { name_translations } do
        #     field :ru, value: ->(name) { name['ru'] }
        #     field :en, value: ->(name) { name['en'] }
        #   end
        #
        # Off course it is possible to define object fields contents dynamically
        # but make sure evaluation proc returns hash:
        #
        #   field :name, type: 'object', value: -> { name_translations }
        #
        # The special case is `multi_field`. In that case field composition
        # changes satisfy elasticsearch rules:
        #
        #   field :full_name, type: 'multi_field', value: ->{ full_name.try(:strip) } do
        #     field :full_name, index: 'analyzed', analyzer: 'name'
        #     field :sorted, index: 'analyzed', analyzer: 'sorted'
        #   end
        #
        def field *args, &block
          options = args.extract_options!
          build_root unless root_object

          if args.size > 1
            args.map { |name| field(name, options) }
          else
            expand_nested(Chewy::Fields::Default.new(args.first, options), &block)
          end
        end

        # Defines dynamic template in mapping root objests
        #
        #   class CarsIndex < Chewy::Index
        #     define_type Car do
        #       template 'model.*', type: 'string', analyzer: 'special'
        #       field 'model', type: 'object' # here we can put { ru: 'Мерседес', en: 'Mercedes' }
        #                                     # and template will be applyed to this field
        #     end
        #   end
        #
        # Name for each template is generated with the following
        # rule: "template_#{dynamic_templates.size + 1}".
        #
        #   template 'tit*', mapping_hash
        #   template 'title.*', mapping_hash # dot in template causes "path_match" using
        #   template /tit.+/, mapping_hash # using "match_pattern": "regexp"
        #   template /title\..+/, mapping_hash # "\." - escaped dot causes "path_match" using
        #   template /tit.+/, 'string' mapping_hash # "match_mapping_type" as the optionsl second argument
        #   template template42: {match: 'hello*', mapping: {type: 'object'}} # or even pass a template as is
        #
        def template *args
          build_root unless root_object

          root_object.dynamic_template *args
        end
        alias_method :dynamic_template, :template

        # Returns compiled mappings hash for current type
        #
        def mappings_hash
          root_object ? root_object.mappings_hash : {}
        end

      private

        def expand_nested field, &block
          @_current_field.nested(field) if @_current_field
          if block
            previous_field, @_current_field = @_current_field, field
            block.call
            @_current_field = previous_field
          end
        end

        def build_root options = {}, &block
          self.root_object = Chewy::Fields::Root.new(type_name, options)
          expand_nested(self.root_object, &block)
          @_current_field = self.root_object
        end
      end
    end
  end
end

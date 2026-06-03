module Chewy
  class Index
    # Compiled compose path. Default for all indexes.
    #
    # Generates a single `__chewy_compose__` method per index from the
    # field tree (no Ruby source parsing of user procs). Bakes the
    # per-field arity into the call site and inlines hash construction,
    # removing the per-field iteration + dispatch overhead of the legacy
    # plain compose path. Proc bodies are NOT inlined — procs are called
    # via `.call`. In exchange there are no parser/unparser/method_source
    # deps and no Ruby/Prism version coupling.
    #
    # `fields:` selection is supported: a dedicated method is generated
    # and memoized per unique fields set.
    #
    # Falls back to the plain `Chewy::Fields::Root#compose` path when the
    # field tree uses features the compiler does not handle:
    # ignore_blank, geo_point, custom root value.
    module Compiled
      extend ActiveSupport::Concern

      class UNSUPPORTED < StandardError
      end

      COMPILE_MUTEX = Mutex.new

      module ClassMethods
        # Returns true when this index can use the compiled path for the
        # given compose call. Builds the per-fields method if needed.
        def compiled_compose_available?(fields)
          return false if witchcraft?
          return false unless root&.children&.present?

          ensure_compiled_compose_for!(fields)
        rescue UNSUPPORTED
          false
        end

        def compiled_compose(object, crutches, context, fields)
          send(compiled_method_name(fields), object, crutches, context)
        end

        def compiled_procs
          @compiled_procs ||= []
        end

        # Build (and cache) the compiled compose method for the given
        # fields restriction. Returns true on success, false / raises on
        # unsupported. Thread-safe: compilation under a process-wide
        # mutex prevents two threads from interleaving appends into
        # @compiled_procs and baking duplicate indices into class_eval'd
        # method bodies.
        def ensure_compiled_compose_for!(fields)
          key = fields_key(fields)
          built = (@compiled_compose_built ||= {})
          return built[key] if built.key?(key)

          COMPILE_MUTEX.synchronize do
            return built[key] if built.key?(key)

            method_name = compiled_method_name(fields)
            source      = Compiler.new(self, fields: fields, method_name: method_name).build
            class_eval(source, __FILE__, __LINE__)
            built[key] = true
          end
        rescue UNSUPPORTED
          (@compiled_compose_built ||= {})[fields_key(fields)] = false
          raise
        end

        # Clears compiled-method cache and rebuilds-on-next-call. Hooked
        # from `Mapping.field` so a `field` added after the first compose
        # is picked up rather than absent from a stale generated method.
        # Existing singleton methods remain defined (they shadow until
        # rebuilt) but the cache flag is dropped so the next compose
        # rebuilds and reassigns them.
        def invalidate_compiled_compose!
          @compiled_compose_built = nil
          @compiled_procs = nil
          @compiled_default_ready = false
        end

        def compiled_method_name(fields)
          key = fields_key(fields)
          return :__chewy_compose__ if key.empty?

          :"__chewy_compose__#{key}"
        end

      private

        # Distinct field sets are kept distinct by hashing the joined,
        # sorted symbol names rather than joining with a separator that
        # collides with `_` inside field names (e.g. [:full_name, :id]
        # vs [:full, :name_id]). Hex-encoding the digest keeps the
        # method name a valid Ruby identifier.
        def fields_key(fields)
          return ''.freeze if fields.nil? || fields.empty?

          require 'digest'
          Digest::SHA1.hexdigest(fields.map(&:to_sym).sort.join("\0"))[0, 12]
        end

      end

      class Compiler
        def initialize(index, fields: [], method_name: :__chewy_compose__)
          @index       = index
          @procs       = index.compiled_procs
          @counter     = 0
          @fields      = fields.map(&:to_sym)
          @method_name = method_name
        end

        def build
          check_root_value!(@index.root)
          body = compose_children_src(@index.root, 'o0', restrict: @fields)
          <<~RUBY
            def self.#{@method_name}(o0, crutches, context)
              #{body}.as_json
            end
          RUBY
        end

      private

        def check_root_value!(root)
          v = root.instance_variable_get(:@value)
          return if v.equal?(Chewy::Fields::Root::DEFAULT_VALUE)

          raise UNSUPPORTED, 'custom root value proc not supported by compiled path'
        end

        def compose_children_src(parent_field, obj_var, restrict: [])
          children = parent_field.children
          children = children.select { |f| restrict.include?(f.name) } if restrict.any?
          # Plain Base#compose_children merges per-field hashes, so a field
          # redeclared with the same name is silently last-wins. Match that
          # here to avoid Ruby's "duplicate key" warning on the generated
          # literal hash.
          children = children.reverse.uniq(&:name).reverse

          pairs = children.map do |f|
            raise UNSUPPORTED, "field #{f.name}" if unsupported?(f)

            # Use Ruby's literal-inspect for the key so names with quotes,
            # backslashes, `#{}`, or other special characters are safely
            # serialised — never raw-interpolated into source.
            "#{f.name.to_s.inspect} => #{field_value_src(f, obj_var)}"
          end
          "{ #{pairs.join(', ')} }"
        end

        # Features the compiler refuses; caller falls back to plain.
        # Join fields are supported via Field#value returning a proc.
        def unsupported?(field)
          return true if field.options.key?(:ignore_blank)
          return true if field.options[:type].to_s == 'geo_point'

          false
        end

        def field_value_src(field, parent_obj_var)
          fetch = fetch_src(field, parent_obj_var)
          return fetch if !field.children.present? || field.multi_field?

          child_var = "o#{next_counter}"
          raw_var   = "#{child_var}_raw"
          children_src = compose_children_src(field, child_var)
          <<~RUBY.chomp
            (#{raw_var} = #{fetch}
            if #{raw_var}.nil?
              nil
            elsif #{raw_var}.respond_to?(:to_ary)
              #{raw_var}.to_ary.map { |#{child_var}| #{children_src} }
            else
              #{child_var} = #{raw_var}
              #{children_src}
            end)
          RUBY
        end

        def fetch_src(field, obj_var)
          v = field.value
          if v.is_a?(Proc)
            idx = @procs.size
            @procs << v
            procs_ref = "compiled_procs[#{idx}]"
            param_count = positional_param_count(v)
            case v.arity
            when 0
              "#{obj_var}.instance_exec(&#{procs_ref})"
            else
              # Pass only as many of (object, crutches, context) as the
              # proc actually declares. This keeps lambdas with optional
              # args (negative arity like `->(o, c=nil)`) from being
              # called with too many arguments. Anything beyond context
              # truncates to all three.
              args = [obj_var, 'crutches', 'context'].first(param_count)
              "#{procs_ref}.call(#{args.join(', ')})"
            end
          else
            method_name = v.is_a?(Symbol) || v.is_a?(String) ? v.to_s : field.name.to_s
            unless safe_identifier?(method_name)
              raise UNSUPPORTED, "non-identifier field accessor: #{method_name.inspect}"
            end

            # Mirror Base#value_by_name_proc: hash key-or-string fallback,
            # method send otherwise.
            "(#{obj_var}.is_a?(Hash) ? " \
              "(#{obj_var}.key?(:#{method_name}) ? #{obj_var}[:#{method_name}] : #{obj_var}['#{method_name}']) : " \
              "#{obj_var}.#{method_name})"
          end
        end

        # Number of positional parameters declared by `proc`, counting
        # required + optional. Splats and keyword args contribute one
        # bucket each so the caller still passes all three context args.
        def positional_param_count(proc)
          params = proc.parameters
          required = params.count { |type, _| %i[req opt].include?(type) }
          has_splat = params.any? { |type, _| type == :rest }
          has_splat ? 3 : [required, 3].min
        end

        IDENTIFIER_RE = /\A[A-Za-z_][A-Za-z0-9_]*[!?=]?\z/

        def safe_identifier?(name)
          IDENTIFIER_RE.match?(name.to_s)
        end

        def next_counter
          @counter += 1
        end
      end
    end
  end
end

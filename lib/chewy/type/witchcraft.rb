def try_require lib
  require lib
rescue LoadError
end

%w[method_source parser/current unparser].each { |lib| try_require lib }

module Chewy
  class Type
    module Witchcraft
      extend ActiveSupport::Concern

      included do
        class_attribute :_witchcraft, instance_reader: false, instance_writer: false
      end

      module ClassMethods
        def witchcraft!
          self._witchcraft = true
          check_requirements!
        end

        def check_requirements!
          messages = []
          messages << "MethodSource gem is required for the Witchcraft, please add `gem 'method_source'` to your Gemfile" unless Proc.method_defined?(:source)
          messages << "Parser gem is required for the Witchcraft, please add `gem 'parser'` to your Gemfile" unless '::Parser'.safe_constantize
          messages << "Unparser gem is required for the Witchcraft, please add `gem 'unparser'` to your Gemfile" unless '::Unparser'.safe_constantize
          messages = messages.join("\n")

          raise messages if messages.present?
        end

        def witchcraft?
          !!_witchcraft
        end

        def cauldron
          @cauldron ||= Cauldron.new(self)
        end
      end

      class Cauldron
        attr_reader :locals

        def initialize(type)
          @type = type
          @locals = []
        end

        def brew(object, crutches = [])
          alicorn.call(locals, object, crutches).as_json
        end

      private

        def alicorn
          @alicorn ||= class_eval <<-RUBY
            -> (locals, object0, crutches) do
              #{composed_values(@type.root_object, 0)}
            end
          RUBY
        end

        def composed_values(field, nesting)
          source = <<-RUBY
            non_proc_values#{nesting} = #{non_proc_values(field, nesting)}
            proc_values#{nesting} = #{proc_values(field, nesting)}
            non_proc_values#{nesting}.merge!(proc_values#{nesting})
          RUBY
          source.gsub("\n,", ',')
        end

        def composed_value(field, fetcher, nesting)
          nesting = nesting.next
          if field.children.present? && !field.multi_field?
            <<-RUBY
              (result#{nesting} = #{fetcher}
              if result#{nesting}.respond_to?(:to_ary)
                result#{nesting}.map do |object#{nesting}|
                  #{composed_values(field, nesting)}
                end
              else
                object#{nesting} = result#{nesting}
                #{composed_values(field, nesting)}
              end)
            RUBY
          else
            fetcher
          end
        end

        def non_proc_values(field, nesting)
          non_proc_fields = non_proc_fields_for(field)
          object = "object#{nesting}"

          if non_proc_fields.present?
            <<-RUBY
              (if #{object}.is_a?(Hash)
                {
                  #{non_proc_fields.map do |field|
                    fetcher = "#{object}.has_key?(:#{field.name}) ? #{object}[:#{field.name}] : #{object}['#{field.name}']"
                    "#{field.name}: #{composed_value(field, fetcher, nesting)}"
                  end.join(', ')}
                }
              else
                {
                  #{non_proc_fields.map do |field|
                    "#{field.name}: #{composed_value(field, "#{object}.#{field.name}", nesting)}"
                  end.join(', ')}
                }
              end)
            RUBY
          else
            "{}"
          end
        end

        def proc_values(field, nesting)
          proc_fields = proc_fields_for(field)

          if proc_fields.present?
            <<-RUBY
              {
                #{proc_fields.map do |field|
                  "#{field.name}: (#{composed_value(field, source_for(field.value, nesting), nesting)})"
                end.join(', ')}
              }
            RUBY
          else
            "{}"
          end
        end

        def non_proc_fields_for(parent)
          return [] unless parent
          (parent.children || []).select { |field| !(field.value && field.value.is_a?(Proc)) }
        end

        def proc_fields_for(parent)
          return [] unless parent
          (parent.children || []).select { |field| field.value && field.value.is_a?(Proc) }
        end

        def source_for(proc, nesting)
          ast = Parser::CurrentRuby.parse(proc.source)
          lambdas = exctract_lambdas(ast)

          raise "No lambdas found, try to reformat your code:\n`#{proc.source}`" unless lambdas

          source = lambdas.first
          proc_params = proc.parameters.map(&:second)

          if proc.arity == 0
            source = replace_self(source, :"object#{nesting}")
            source = replace_send(source, :"object#{nesting}")
          elsif proc.arity < 0
            raise "Splat arguments are unsupported by witchcraft:\n`#{proc.source}"
          else
            (nesting + 1).times do |n|
              source = replace_lvar(source, proc_params[n], :"object#{n}") if proc_params[n]
            end

            (proc_params.size - nesting - 1).times do |n|
              m = nesting + 1 + n
              source = replace_crutch(source, proc_params[m], n) if proc_params[m]
            end

            binding_variable_list(source).each do |variable|
              locals.push(proc.binding.eval(variable.to_s))
              source = replace_local(source, variable, locals.size - 1)
            end
          end

          Unparser.unparse(source)
        end

        def exctract_lambdas(node)
          if node.type == :block && node.children[0].type == :send && node.children[0].to_a == [nil, :lambda]
            [node.children[2]]
          else
            node.children.map { |child| exctract_lambdas(child) }.flatten.compact
          end if node.is_a?(Parser::AST::Node)
        end

        def replace_lvar(node, old_variable, new_variable)
          if node.is_a?(Parser::AST::Node)
            if node.type == :lvar && node.children.to_a == [old_variable]
              node.updated(nil, [new_variable])
            else
              node.updated(nil, node.children.map { |child| replace_lvar(child, old_variable, new_variable) })
            end
          else
            node
          end
        end

        def replace_send(node, variable)
          if node.is_a?(Parser::AST::Node)
            if node.type == :send && node.children[0].nil?
              node.updated(nil, [Parser::AST::Node.new(:lvar, [variable]), *node.children[1..-1]])
            else
              node.updated(nil, node.children.map { |child| replace_send(child, variable) })
            end
          else
            node
          end
        end

        def replace_self(node, variable)
          if node.is_a?(Parser::AST::Node)
            if node.type == :self
              Parser::AST::Node.new(:lvar, [variable])
            else
              node.updated(nil, node.children.map { |child| replace_self(child, variable) })
            end
          else
            node
          end
        end

        def replace_crutch(node, variable, crutch_index)
          if node.is_a?(Parser::AST::Node)
            if node.type == :lvar && node.children.to_a == [variable]
              node.updated(:send, [
                Parser::AST::Node.new(:lvar, [:crutches]),
                :[],
                Parser::AST::Node.new(:int, [crutch_index])
              ])
            else
              node.updated(nil, node.children.map { |child| replace_crutch(child, variable, crutch_index) })
            end
          else
            node
          end
        end

        def replace_local(node, variable, local_index)
          if node.is_a?(Parser::AST::Node)
            if node.type == :send && node.children.to_a == [nil, variable]
              node.updated(nil, [
                Parser::AST::Node.new(:lvar, [:locals]),
                :[],
                Parser::AST::Node.new(:int, [local_index])
              ])
            else
              node.updated(nil, node.children.map { |child| replace_local(child, variable, local_index) })
            end
          else
            node
          end
        end

        def binding_variable_list(node)
          if node.type == :send && node.children[0].nil?
            node.children[1]
          else
            node.children.map { |child| binding_variable_list(child) }.flatten.compact.uniq
          end if node.is_a?(Parser::AST::Node)
        end
      end
    end
  end
end

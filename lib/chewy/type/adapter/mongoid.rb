require 'chewy/type/adapter/base'

module Chewy
  class Type
    module Adapter
      class Mongoid < Base
        def initialize *args
          @options = args.extract_options!
          subject = args.first
          if subject.is_a?(::Mongoid::Criteria)
            @model = subject.klass
            @scope = subject
          else
            @model = subject
          end
        end

        def name
          @name ||= (options[:name].present? ? options[:name].to_s.camelize : model.model_name.to_s).demodulize
        end

        # Import method for Mongoid takes import data and import options
        #
        # Import data types:
        #
        #   * Nothing passed - imports all the model data
        #   * ActiveRecord scope
        #   * Objects collection
        #   * Ids collection
        #
        # Import options:
        #
        #   <tt>:batch_size</tt> - import batch size, 1000 objects by default
        #
        # Method handles destroyed objects as well. In case of objects AcriveRecord::Relation
        # or array passed, objects, responding with true to `destroyed?` method will be deleted
        # from index. In case of ids array passed - documents with missing records ids will be
        # deleted from index:
        #
        #   users = User.all
        #   users.each { |user| user.destroy if user.incative? }
        #   UsersIndex::User.import users # inactive users will be deleted from index
        #   # or
        #   UsersIndex::User.import users.map(&:id) # deleted user ids will be deleted from index
        #
        # Also there is custom API method `delete_from_index?`. It it returns `true`
        # object will be deleted from index. Note that if this method is defined and
        # return `false` Chewy will still check `destroyed?` method. This is useful
        # for paranoid objects sdeleting implementation.
        #
        #   class User
        #     alias_method :delete_from_index?, :deleted_at?
        #   end
        #
        #   users = User.all
        #   users.each { |user| user.deleted_at = Time.now }
        #   UsersIndex::User.import users # paranoid deleted users will be deleted from index
        #   # or
        #   UsersIndex::User.import users.map(&:id) # user ids will be deleted from index
        #
        def import *args, &block
          import_options = args.extract_options!
          batch_size = import_options[:batch_size] || BATCH_SIZE

          collection = args.empty? ? model_all :
            (args.one? && args.first.is_a?(::Mongoid::Criteria) ? args.first : args.flatten.compact)

          if collection.is_a?(::Mongoid::Criteria)
            batch_process(collection, batch_size) do |batch|
              block.call grouped_objects(batch)
            end
          else
            objects, ids = collection.partition { |object| object.is_a?(::Mongoid::Document) }
            import_objects(objects, batch_size, &block) && import_ids(ids, batch_size, &block)
          end
        end

        def load *args
          load_options = args.extract_options!
          objects = args.flatten

          additional_scope = load_options[load_options[:_type].type_name.to_sym].try(:[], :scope) || load_options[:scope]

          scope = scoped_model(objects.map(&:id))
          loaded_objects = if additional_scope.is_a?(Proc)
            scope.instance_exec(&additional_scope)
          elsif additional_scope.is_a?(::Mongoid::Criteria)
            scope.merge(additional_scope)
          else
            scope
          end.index_by { |object| object.id.to_s }

          objects.map { |object| loaded_objects[object.id.to_s] }
        end

      private

        attr_reader :model, :scope, :options

        def import_objects(objects, batch_size, &block)
          objects.each_slice(batch_size).all? do |group|
            block.call grouped_objects(group)
          end
        end

        def import_ids(ids, batch_size)
          ids.uniq!

          indexed = batch_process(scoped_model(ids), batch_size) do |batch|
            ids -= batch.map(&:id)
            yield grouped_objects(batch)
          end

          deleted = ids.each_slice(batch_size).all? do |group|
            yield delete: group
          end

          indexed && deleted
        end

        def grouped_objects(objects)
          objects.group_by do |object|
            delete = object.delete_from_index? if object.respond_to?(:delete_from_index?)
            delete ||= object.destroyed?
            delete ? :delete : :index
          end
        end

        def batch_process(collection, batch_size, &block)
          merged_scope(collection).batch_size(batch_size)
            .no_timeout.each_slice(batch_size).all?(&block)
        end

        def merged_scope(target)
          scope ? scope.clone.merge(target) : target
        end

        def scoped_model(ids)
          model.where(:_id.in => ids)
        end

        def model_all
          model.all
        end
      end
    end
  end
end

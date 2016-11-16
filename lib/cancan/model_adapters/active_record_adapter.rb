module CanCan
  module ModelAdapters
    module ActiveRecordAdapter
      def database_records
        if override_scope
          @model_class.where(nil).merge(override_scope)
        else
          positive_relations = []
          negative_relations = []
          @rules.reverse.each do |rule|
            if rule.base_behavior
              positive_relations << relation_for(rule)
            else
              negative_relations << relation_for(rule)
            end
          end
          if positive_relations.empty?
            @model_class.where('1 == 0')
          else
            positive_sql = positive_relations.map(&:to_sql).join(' UNION ')
            if negative_relations.empty?
              @model_class.select("DISTINCT #{@model_class.table_name}.*").from("(#{positive_sql}) AS #{@model_class.table_name}")
            else
              negative_sql = negative_relations.map(&:to_sql).join(' EXCEPT ')
              @model_class.select("DISTINCT #{@model_class.table_name}.*").from("(#{positive_sql} EXCEPT #{negative_sql}) AS #{@model_class.table_name}")
            end
          end
        end
      end
      
      private

      def relation_for(rule)
        @model_class.where(tableized_conditions(rule.conditions)).joins(joins_for(rule))
      end

      def tableized_conditions(conditions, model_class = @model_class)
        return conditions unless conditions.kind_of? Hash
        conditions.inject({}) do |result_hash, (name, value)|
          if value.kind_of? Hash
            value = value.dup
            association_class = model_class.reflect_on_association(name).klass.name.constantize
            nested = value.inject({}) do |nested,(k,v)|
              if v.kind_of? Hash
                value.delete(k)
                nested[k] = v
              else
                result_hash[model_class.reflect_on_association(name).table_name.to_sym] = value
              end
              nested
            end
            result_hash.merge!(tableized_conditions(nested,association_class))
          else
            result_hash[name] = value
          end
          result_hash
        end
      end

      def override_scope
        conditions = @rules.map(&:conditions).compact
        if defined?(ActiveRecord::Relation) && conditions.any? { |c| c.kind_of?(ActiveRecord::Relation) }
          if conditions.size == 1
            conditions.first
          else
            rule = @rules.detect { |rule| rule.conditions.kind_of?(ActiveRecord::Relation) }
            raise Error, "Unable to merge an Active Record scope with other conditions. Instead use a hash or SQL for #{rule.actions.first} #{rule.subjects.first} ability."
          end
        end
      end

      def joins_for(rule)
        joins_hash = rule.associations_hash
        clean_joins(joins_hash) unless joins_hash.empty?
      end

      # Removes empty hashes and moves everything into arrays.
      def clean_joins(joins_hash)
        joins = []
        joins_hash.each do |name, nested|
          joins << (nested.empty? ? name : {name => clean_joins(nested)})
        end
        joins
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  include CanCan::ModelAdditions
end

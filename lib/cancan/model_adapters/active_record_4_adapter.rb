module CanCan
  module ModelAdapters
    class ActiveRecord4Adapter < AbstractAdapter
      include ActiveRecordAdapter
      def self.for_class?(model_class)
        model_class <= ActiveRecord::Base
      end

      private

      def self.override_condition_matching?(subject, name, _value)
        # ActiveRecord introduced enums in version 4.1.
        (ActiveRecord::VERSION::MAJOR > 4 || ActiveRecord::VERSION::MINOR >= 1) &&
          subject.class.defined_enums.include?(name.to_s)
      end

      def self.matches_condition?(subject, name, value)
        # Get the mapping from enum strings to values.
        enum = subject.class.send(name.to_s.pluralize)
        # Get the value of the attribute as an integer.
        attribute = enum[subject.send(name)]
        # Check to see if the value matches the condition.
        value.is_a?(Enumerable) ? 
          (value.include? attribute) :
          attribute == value
      end
    end
  end
end

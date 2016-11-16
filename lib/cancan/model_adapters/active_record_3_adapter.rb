module CanCan
  module ModelAdapters
    class ActiveRecord3Adapter < AbstractAdapter
      include ActiveRecordAdapter
      def self.for_class?(model_class)
        model_class <= ActiveRecord::Base
      end
    end
  end
end

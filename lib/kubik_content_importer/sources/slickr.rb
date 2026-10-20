# frozen_string_literal: true

module KubikContentImporter
  module Sources
    class Slickr
      def initialize(model_class_name)
        @model_class = model_class_name.constantize
      end

      def each_record
        runner = -> { @model_class.find_each { |record| yield record } }
        if legacy_role_available?
          ActiveRecord::Base.connected_to(role: :legacy, prevent_writes: true) { runner.call }
        else
          runner.call
        end
      end

      private

      def legacy_role_available?
        ActiveRecord::Base.connection_handler.connection_pool_configs.any? do |c|
          c.name.to_s == 'legacy'
        end
      rescue StandardError
        false
      end
    end
  end
end

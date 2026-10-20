# frozen_string_literal: true

module KubikContentImporter
  class NavigationIdMap
    class << self
      def register(slickr_id, kubik_id)
        @map ||= {}
        @map[slickr_id.to_i] = kubik_id.to_i
      end

      def kubik_id_for(slickr_id)
        return nil if slickr_id.blank?

        sid = slickr_id.to_i
        @map&.fetch(sid, nil) || sid
      end

      def reset!
        @map = {}
      end
    end
  end
end

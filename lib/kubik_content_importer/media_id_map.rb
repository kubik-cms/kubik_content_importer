# frozen_string_literal: true

module KubikContentImporter
  # In-memory map populated while importing media uploads (slickr id → kubik id).
  class MediaIdMap
    LEGACY_KEY = 'legacy_slickr_media_upload_id'

    class << self
      def reset!
        @map = {}
      end

      def register(slickr_id, kubik_id)
        @map ||= {}
        @map[slickr_id.to_i] = kubik_id.to_i
      end

      def kubik_id_for(slickr_id)
        return nil if slickr_id.blank?

        sid = slickr_id.to_i
        @map&.fetch(sid, nil) || lookup_from_db(sid)
      end

      def lookup_from_db(slickr_id)
        return nil unless defined?(Kubik::MediaUpload)

        Kubik::MediaUpload
          .where("additional_info ->> ? = ?", LEGACY_KEY, slickr_id.to_s)
          .pick(:id)
      end
    end
  end
end

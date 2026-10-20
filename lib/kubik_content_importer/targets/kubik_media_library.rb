# frozen_string_literal: true

require 'kubik_content_importer/records/slickr_media_upload'

module KubikContentImporter
  module Targets
    class KubikMediaLibrary
      BATCH_SIZE = 200

      def initialize(dry_run: false)
        @dry_run = dry_run
      end

      def import!
        raise 'Kubik::MediaUpload is not available' unless defined?(Kubik::MediaUpload)

        MediaIdMap.reset!
        scope = Records::SlickrMediaUpload.order(:id)
        total = scope.count
        Rails.logger.info "[kubik_content_importer] Importing #{total} slickr_media_uploads → kubik_media_uploads"

        imported = 0
        skipped = 0

        scope.find_in_batches(batch_size: BATCH_SIZE) do |batch|
          batch.each do |slickr_row|
            if import_row!(slickr_row)
              imported += 1
            else
              skipped += 1
            end
          end
        end

        reset_id_sequence! unless @dry_run
        Rails.logger.info "[kubik_content_importer] media_uploads done: imported=#{imported} skipped=#{skipped}"
        { imported: imported, skipped: skipped, total: total }
      end

      private

      def import_row!(slickr_row)
        legacy_id = slickr_row.id
        existing_kubik_id = MediaIdMap.lookup_from_db(legacy_id)

        if existing_kubik_id
          MediaIdMap.register(legacy_id, existing_kubik_id)
          return false
        end

        if @dry_run
          Rails.logger.info("[kubik_content_importer] dry-run media_upload id=#{legacy_id}")
          MediaIdMap.register(legacy_id, legacy_id)
          return true
        end

        additional_info = (slickr_row.additional_info || {}).dup
        additional_info[MediaIdMap::LEGACY_KEY] = legacy_id

        attrs = {
          id: legacy_id,
          image_data: slickr_row.image_data || {},
          file_data: slickr_row.file_data || {},
          additional_info: additional_info,
          aasm_state: slickr_row.aasm_state.presence || 'ready',
          created_at: slickr_row.created_at,
          updated_at: slickr_row.updated_at
        }

        Kubik::MediaUpload.upsert(attrs, unique_by: :id)
        MediaIdMap.register(legacy_id, legacy_id)
        true
      end

      def reset_id_sequence!
        max_id = Kubik::MediaUpload.maximum(:id)
        return if max_id.blank?

        Kubik::MediaUpload.connection.execute(
          "SELECT setval(pg_get_serial_sequence('kubik_media_uploads', 'id'), #{max_id.to_i}, true)"
        )
      end
    end
  end
end

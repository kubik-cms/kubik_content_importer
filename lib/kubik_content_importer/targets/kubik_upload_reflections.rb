# frozen_string_literal: true

require 'kubik_content_importer/records/slickr_upload'

module KubikContentImporter
  module Targets
    class KubikUploadReflections
      def initialize(dry_run: false)
        @dry_run = dry_run
      end

      def import!
        raise 'Kubik::Upload is not available' unless defined?(Kubik::Upload)

        imported = 0
        skipped = 0

        Records::SlickrUpload.find_each do |slickr_upload|
          result = import_row!(slickr_upload)
          case result
          when :imported then imported += 1
          else skipped += 1
          end
        end

        Rails.logger.info "[kubik_content_importer] upload_reflections done: imported=#{imported} skipped=#{skipped}"
        { imported: imported, skipped: skipped }
      end

      private

      def import_row!(slickr_upload)
        status, kubik_type, uploadable_id = UploadReflectionMapper.resolve(slickr_upload)
        if status == :skip
          Rails.logger.debug("[kubik_content_importer] skip upload #{slickr_upload.id}: #{kubik_type}")
          return :skipped
        end

        kubik_media_id = MediaIdMap.kubik_id_for(slickr_upload.slickr_media_upload_id)
        if kubik_media_id.blank?
          Rails.logger.warn(
            "[kubik_content_importer] skip upload #{slickr_upload.id}: missing kubik media for slickr_media_upload_id=#{slickr_upload.slickr_media_upload_id}"
          )
          return :skipped
        end

        if @dry_run
          Rails.logger.info(
            "[kubik_content_importer] dry-run upload #{slickr_upload.id} → #{kubik_type}##{uploadable_id} media=#{kubik_media_id}"
          )
          return :imported
        end

        target = Kubik::Upload.find_or_initialize_by(
          uploadable_type: kubik_type,
          uploadable_id: uploadable_id
        )
        target.assign_attributes(
          kubik_media_upload_id: kubik_media_id,
          additional_info: slickr_upload.additional_info || {},
          position: slickr_upload.position
        )
        target.save!
        :imported
      end
    end
  end
end

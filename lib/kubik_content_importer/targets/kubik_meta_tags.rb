# frozen_string_literal: true

require 'kubik_content_importer/records/slickr_meta_tag'

module KubikContentImporter
  module Targets
    class KubikMetaTags
      METATAGABLE_TYPE_MAP = {
        'Slickr::Page' => 'Page'
      }.freeze

      def initialize(dry_run: false)
        @dry_run = dry_run
      end

      def import!
        raise 'Kubik::MetaTag is not available' unless defined?(Kubik::MetaTag)

        imported = 0
        skipped = 0

        Records::SlickrMetaTag.find_each do |slickr_tag|
          if import_row!(slickr_tag)
            imported += 1
          else
            skipped += 1
          end
        end

        Rails.logger.info "[kubik_content_importer] meta_tags done: imported=#{imported} skipped=#{skipped}"
        { imported: imported, skipped: skipped }
      end

      private

      def import_row!(slickr_tag)
        kubik_type = METATAGABLE_TYPE_MAP.fetch(slickr_tag.metatagable_type, slickr_tag.metatagable_type)
        kubik_id = resolve_metatagable_id(kubik_type, slickr_tag.metatagable_id)
        return false if kubik_id.blank?

        if @dry_run
          Rails.logger.info("[kubik_content_importer] dry-run meta_tag slickr_id=#{slickr_tag.id} #{kubik_type}##{kubik_id}")
          return true
        end

        target = Kubik::MetaTag.find_or_initialize_by(
          metatagable_type: kubik_type,
          metatagable_id: kubik_id
        )
        target.assign_attributes(
          title_tag: slickr_tag.title_tag,
          meta_description: slickr_tag.meta_description,
          og_title: slickr_tag.og_title,
          og_description: slickr_tag.og_description,
          twitter_title: slickr_tag.twitter_title,
          twitter_description: slickr_tag.twitter_description
        )
        target.save!
        true
      end

      def resolve_metatagable_id(kubik_type, legacy_id)
        return legacy_id unless kubik_type == 'Page' && defined?(Page)

        Page.find_by(legacy_slickr_id: legacy_id)&.id
      end
    end
  end
end

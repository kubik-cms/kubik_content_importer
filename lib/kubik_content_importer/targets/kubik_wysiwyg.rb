# frozen_string_literal: true

module KubikContentImporter
  module Targets
    class KubikWysiwyg
      SLICKR_PAGE_ATTRS = %i[
        title slug aasm_state record_type slickr_page_id active_draft_id published_draft_id
        page_header page_intro page_subheader layout
        meta_title meta_description og_title og_title_2 og_description og_description_2 og_image og_image_2
        page_header_image published_at publish_schedule_date publish_schedule_time discarded_at
        admin_user_id video_url video_captions_url
      ].freeze

      def initialize(model_class_name, dry_run: false)
        @model_class = model_class_name.constantize
        @dry_run = dry_run
      end

      def upsert_from_slickr(record, slug_key: :slug)
        attrs = build_attributes(record, slug_key)
        return Rails.logger.info("[kubik_content_importer] dry-run #{attrs[:slug]}") if @dry_run

        target = @model_class.find_or_initialize_by(slug: attrs[:slug])
        target.assign_attributes(attrs.except(:slug))
        target.save!
        import_call_to_action(record, target)
      end

      private

      def build_attributes(record, slug_key)
        slug = record.public_send(slug_key)
        base = {
          slug: slug,
          title: record.try(:title).presence || slug.to_s.humanize,
          content: transform_wysiwyg(record.try(:content)),
          page_header: record.try(:page_header) || record.try(:header),
          page_subheader: record.try(:page_subheader) || record.try(:subheader),
          layout: record.try(:layout),
          legacy_slickr_id: record.id
        }

        SLICKR_PAGE_ATTRS.each do |attr|
          next unless record.respond_to?(attr)
          next if base.key?(attr)

          value = record.public_send(attr)
          base[attr] = value unless value.nil?
        end

        if record.has_attribute?(:type)
          base[:record_type] = record.read_attribute(:type)
        end

        base[:published_at] = infer_published_at(record, base[:published_at])

        base.compact
      end

      def infer_published_at(record, published_at)
        return published_at if published_at.present?

        state = record.try(:aasm_state)
        return nil if state.present? && state != 'live_version'

        record.try(:created_at) || Time.current
      end

      def transform_wysiwyg(raw)
        normalized = WysiwygPayload.normalize(raw)
        return raw if normalized.blank?

        JSON.parse(normalized)
      end

      def import_call_to_action(source, target)
        return unless target.respond_to?(:reading_schools_call_to_action)

        cta = find_source_call_to_action(source)
        return if cta.blank?

        target_cta = target.reading_schools_call_to_action || target.build_reading_schools_call_to_action
        target_cta.assign_attributes(
          header: cta.header,
          content: cta.content,
          link_path: cta.link_path,
          link_text: cta.link_text,
          published: cta.published
        )
        target_cta.page = target
        target_cta.save!
      rescue StandardError => e
        Rails.logger.warn("[kubik_content_importer] CTA import skipped for #{target.slug}: #{e.message}")
      end

      def find_source_call_to_action(source)
        if source.class.reflect_on_association(:reading_schools_call_to_action)
          source.reading_schools_call_to_action
        elsif defined?(ReadingSchools::CallToAction)
          ReadingSchools::CallToAction.find_by(slickr_page_id: source.id)
        end
      end
    end
  end
end

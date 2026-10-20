# frozen_string_literal: true

require 'securerandom'
require 'kubik_content_importer/records/slickr_navigation'

module KubikContentImporter
  module Targets
    class KubikNavigation
      SLICKR_MASTER_ID = Records::SlickrNavigation::SLICKR_MASTER_ID

      def initialize(dry_run: false)
        @dry_run = dry_run
      end

      def import!
        rows = Records::SlickrNavigation.order(:id).to_a
        importable = rows.reject { |row| row.id == SLICKR_MASTER_ID }
        total = importable.size

        Rails.logger.info "[kubik_content_importer] Importing #{total} slickr_navigations → kubik_navigation_items"

        if @dry_run
          importable.each { |row| Rails.logger.info("[kubik_content_importer] dry-run nav id=#{row.id} #{row.title}") }
          return
        end

        NavigationIdMap.reset!
        Kubik::NavigationItem.transaction do
          Kubik::NavigationItem.delete_all
          importable.each { |row| upsert_row(row) }
          reset_id_sequence!
        end
        Kubik::NavigationItem.bust_cache!

        Rails.logger.info "[kubik_content_importer] navigation_items done: imported=#{importable.size}"
      end

      private

      def upsert_row(row)
        item = Kubik::NavigationItem.new(id: row.id)
        item.assign_attributes(build_attributes(row))
        item.save!
        NavigationIdMap.register(row.id, item.id)
      end

      def display_title(row)
        row.title.presence || row.link_text.presence || "Navigation #{row.id}"
      end

      def build_attributes(row)
        attrs = {
          title: display_title(row),
          text: row.text,
          position: row.position,
          ancestry: kubik_ancestry(row.ancestry),
          open_in_new_window: external_link?(row.link),
          config_setup: row.config_string
        }

        case row.child_type
        when 'Header'
          attrs.merge(item_type: 'header', slug: slugify(row.title))
        when 'Custom Link'
          attrs.merge(
            item_type: 'link',
            slug: slugify(row.title),
            link_location: row.link.presence || '#'
          )
        when 'Page'
          attrs.merge(page_attrs(row))
        else
          if row.root_type == 'Root'
            attrs.merge(item_type: 'node', slug: slugify(row.title))
          else
            attrs.merge(item_type: 'node', slug: slugify(row.title))
          end
        end
      end

      def page_attrs(row)
        page = resolve_page(row.slickr_page_id)
        slug = page&.slug.presence || slickr_page_slug(row.slickr_page_id) || slugify(row.title)

        if page
          {
            item_type: 'resource',
            resource_type: 'Page',
            resource_id: page.id,
            slug: slug_segment(slug),
            controller: 'pages',
            action: 'show',
            params: { 'id' => page.id.to_s, 'kubik_scope' => 'published' }
          }
        else
          path = slickr_page_path(row.slickr_page_id) || "/#{slug_segment(slug)}"
          {
            item_type: 'link',
            slug: slug_segment(slug),
            link_location: path
          }
        end
      end

      def resolve_page(slickr_page_id)
        return nil if slickr_page_id.blank?
        return nil unless defined?(Page)

        Page.find_by(legacy_slickr_id: slickr_page_id) ||
          Page.find_by(slug: slickr_page_slug(slickr_page_id))
      end

      def slickr_page_slug(slickr_page_id)
        return nil if slickr_page_id.blank?

        ActiveRecord::Base.connection.select_value(<<~SQL.squish)
          SELECT slug FROM slickr_pages WHERE id = #{slickr_page_id.to_i} LIMIT 1
        SQL
      end

      def slickr_page_path(slickr_page_id)
        slug = slickr_page_slug(slickr_page_id)
        return nil if slug.blank?

        "/#{slug.to_s.delete_prefix('/')}"
      end

      def kubik_ancestry(ancestry)
        return nil if ancestry.blank?

        normalized = ancestry.to_s
        return nil if normalized == SLICKR_MASTER_ID.to_s

        normalized.delete_prefix("#{SLICKR_MASTER_ID}/").presence
      end

      def slugify(value)
        value.to_s.parameterize.presence || "item-#{SecureRandom.hex(3)}"
      end

      def slug_segment(slug)
        slug.to_s.split('/').reject(&:blank?).last || slugify(slug)
      end

      def external_link?(link)
        link.to_s.match?(%r{\Ahttps?://}i)
      end

      def reset_id_sequence!
        max_id = Kubik::NavigationItem.maximum(:id)
        return if max_id.blank?

        ActiveRecord::Base.connection.execute(<<~SQL.squish)
          SELECT setval(pg_get_serial_sequence('kubik_navigation_items', 'id'), #{max_id.to_i}, true)
        SQL
      end
    end
  end
end

# frozen_string_literal: true

require 'kubik_content_importer/records/slickr_meta_tag'

module KubikContentImporter
  module UploadReflectionMapper
    META_OG = /\A(.+)_meta_og_image\z/
    META_TWITTER = /\A(.+)_meta_twitter_image\z/

    META_METATAGABLE_TYPE_BY_PREFIX = {
      'reading_schools_article' => 'ReadingSchools::Article',
      'reading_schools_resource' => 'ReadingSchools::Resource',
      'reading_schools_process_step' => 'ReadingSchools::ProcessStep',
      'slickr_page' => 'Slickr::Page'
    }.freeze

    DIRECT_TYPE_MAP = {
      'article_image' => 'reading_schools_article_article_image',
      'article_listing_image' => 'reading_schools_article_article_listing_image',
      'resource_image' => 'reading_schools_resource_resource_image',
      'resource_listing_image' => 'reading_schools_resource_resource_listing_image',
      'process_step_image' => 'reading_schools_process_step_process_step_image',
      'banner_cta_image' => 'banner_cta_banner_cta_image',
      'slickr_page_header_image' => 'page_header_image'
    }.freeze

    module_function

    def resolve(slickr_upload)
      type = slickr_upload.uploadable_type
      uploadable_id = slickr_upload.uploadable_id

      if (match = type.match(META_OG))
        meta_image_reflection(match[1], uploadable_id, :og_image_upload)
      elsif (match = type.match(META_TWITTER))
        meta_image_reflection(match[1], uploadable_id, :twitter_image_upload)
      elsif type == 'slickr_navigation_image'
        navigation_image_reflection(uploadable_id)
      elsif DIRECT_TYPE_MAP.key?(type)
        direct_reflection(DIRECT_TYPE_MAP[type], uploadable_id, type)
      else
        [:skip, "unknown uploadable_type #{type}"]
      end
    end

    def direct_reflection(kubik_type, uploadable_id, slickr_type)
      resolved_id =
        case slickr_type
        when 'slickr_page_header_image'
          resolve_page_id(uploadable_id)
        else
          uploadable_id
        end
      return [:skip, "no Kubik record for #{slickr_type} uploadable_id=#{uploadable_id}"] if resolved_id.blank?

      [:ok, kubik_type, resolved_id]
    end

    def meta_image_reflection(table_prefix, metatagable_id, association)
      metatagable_type =
        infer_metatagable_type(metatagable_id) ||
        META_METATAGABLE_TYPE_BY_PREFIX[table_prefix]
      metatagable = resolve_metatagable(metatagable_id, metatagable_type)
      return [:skip, "metatagable not found for id=#{metatagable_id} (#{metatagable_type})"] if metatagable.blank?

      meta_tag = metatagable.meta_tag || metatagable.build_meta_tag
      meta_tag.save! if meta_tag.new_record?

      kubik_type = "kubik_meta_tag_#{association}"
      [:ok, kubik_type, meta_tag.id]
    end

    def infer_metatagable_type(metatagable_id)
      Records::SlickrMetaTag.find_by(metatagable_id: metatagable_id)&.metatagable_type
    end

    def resolve_metatagable(metatagable_id, metatagable_type)
      return nil if metatagable_type.blank?

      klass = normalize_metatagable_type(metatagable_type)
      return nil unless klass

      resolved_id = resolve_metatagable_id(klass, metatagable_id)
      klass.find_by(id: resolved_id)
    end

    def normalize_metatagable_type(type_name)
      case type_name
      when 'Slickr::Page'
        Page if defined?(Page)
      when 'ReadingSchools::Article'
        ReadingSchools::Article if defined?(ReadingSchools::Article)
      when 'ReadingSchools::Resource'
        ReadingSchools::Resource if defined?(ReadingSchools::Resource)
      when 'ReadingSchools::ProcessStep'
        ReadingSchools::ProcessStep if defined?(ReadingSchools::ProcessStep)
      when 'Page'
        Page if defined?(Page)
      else
        type_name.safe_constantize
      end
    end

    def resolve_metatagable_id(klass, legacy_id)
      return legacy_id unless klass == Page && defined?(Page)

      Page.find_by(legacy_slickr_id: legacy_id)&.id || legacy_id
    end

    def resolve_page_id(slickr_page_id)
      return slickr_page_id unless defined?(Page)

      Page.find_by(legacy_slickr_id: slickr_page_id)&.id || slickr_page_id
    end

    def navigation_image_reflection(slickr_navigation_id)
      return [:skip, 'kubik navigation not migrated (no NavigationItem mapping)'] unless defined?(Kubik::NavigationItem)

      kubik_id = NavigationIdMap.kubik_id_for(slickr_navigation_id)
      item = Kubik::NavigationItem.find_by(id: kubik_id)
      return [:skip, "Kubik::NavigationItem missing for slickr_navigation_id=#{slickr_navigation_id}"] if item.blank?

      [:ok, 'kubik_navigation_item_navigation_image', item.id]
    end
  end
end

# frozen_string_literal: true

module KubikContentImporter
  class Runner
    def initialize(only: nil, dry_run: nil)
      @only = Array(only).map(&:to_sym) if only.present?
      @dry_run = dry_run.nil? ? KubikContentImporter.configuration.dry_run : dry_run
    end

    def run!
      mappings = KubikContentImporter.configuration.mappings
      keys = @only || mappings.keys
      keys.each do |key|
        mapping = mappings[key]
        raise ArgumentError, "Unknown resource #{key}" unless mapping

        import_resource(key, mapping)
      end
    end

    private

    def import_resource(key, mapping)
      Rails.logger.info "[kubik_content_importer] Importing #{key}"
      case mapping[:target] || :wysiwyg
      when :wysiwyg
        import_wysiwyg_resource(key, mapping)
      when :media_library
        require 'kubik_content_importer/targets/kubik_media_library'
        Targets::KubikMediaLibrary.new(dry_run: @dry_run).import!
      when :meta_tags
        require 'kubik_content_importer/targets/kubik_meta_tags'
        Targets::KubikMetaTags.new(dry_run: @dry_run).import!
      when :upload_reflections
        require 'kubik_content_importer/upload_reflection_mapper'
        require 'kubik_content_importer/targets/kubik_upload_reflections'
        Targets::KubikUploadReflections.new(dry_run: @dry_run).import!
      when :navigation
        require 'kubik_content_importer/targets/kubik_navigation'
        Targets::KubikNavigation.new(dry_run: @dry_run).import!
      else
        raise ArgumentError, "Unknown importer target #{mapping[:target]} for #{key}"
      end
    end

    def import_wysiwyg_resource(_key, mapping)
      source = Sources::Slickr.new(mapping[:source_model])
      target = Targets::KubikWysiwyg.new(mapping[:target_model], dry_run: @dry_run)
      source.each_record do |record|
        target.upsert_from_slickr(record, slug_key: mapping[:slug_attribute] || :slug)
      end
    end
  end
end

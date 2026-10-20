# frozen_string_literal: true

module KubikContentImporter
  class Configuration
    attr_accessor :source_adapter, :target_adapter, :dry_run, :legacy_connection

    def initialize
      @source_adapter = :slickr
      @target_adapter = :kubik_wysiwyg
      @dry_run = false
      @legacy_connection = :legacy
      @mappings = {}
    end

    def register(resource_key, source_model: nil, target_model: nil, **options)
      @mappings[resource_key.to_sym] = {
        source_model: source_model,
        target_model: target_model,
        **options
      }.compact
    end

    def mappings
      @mappings
    end
  end
end

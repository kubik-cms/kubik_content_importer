# frozen_string_literal: true

require 'kubik_content_importer/version'
require 'kubik_content_importer/configuration'
require 'kubik_content_importer/engine'
require 'kubik_content_importer/draftjs_inline_html'
require 'kubik_content_importer/editorjs_header_text'
require 'kubik_content_importer/editorjs_nested_list'
require 'kubik_content_importer/draftjs_to_editorjs'
require 'kubik_content_importer/wysiwyg_payload'
require 'kubik_content_importer/runner'
require 'kubik_content_importer/media_id_map'
require 'kubik_content_importer/navigation_id_map'
require 'kubik_content_importer/sources/slickr'
require 'kubik_content_importer/targets/kubik_wysiwyg'

module KubikContentImporter
  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def run!(**options)
      Runner.new(**options).run!
    end
  end
end

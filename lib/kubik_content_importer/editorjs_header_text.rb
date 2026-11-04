# frozen_string_literal: true

require 'cgi'

module KubikContentImporter
  # Editor.js header blocks should store plain text. Draft.js BOLD on header-* blocks becomes
  # <strong> markup that older public renderers stripped entirely.
  module EditorjsHeaderText
    module_function

    def plain_text(html)
      s = html.to_s
      return s.strip if s !~ /<[a-z]/i

      s = s.gsub(/<br\s*\/?>/i, ' ')
      s = s.gsub(%r{</a>}i, ' ')
      s = s.gsub(/<a\b[^>]*>/i, '')
      s = s.gsub(/<\/?(?:strong|em|b|i)[^>]*>/i, '')
      s = s.gsub(/<[^>]+>/, '')
      CGI.unescapeHTML(s).gsub(/\s+/, ' ').strip
    end

    def needs_repair?(text)
      raw = text.to_s
      return false if raw.blank?
      return false if raw !~ /<[a-z]/i

      plain_text(raw) != raw.strip
    end

    def document_needs_repair?(document)
      return false unless document.is_a?(Hash)

      Array(document['blocks']).any? do |block|
        block['type'] == 'header' && needs_repair?(block.dig('data', 'text'))
      end
    end

    def normalize_document!(document)
      return document unless document.is_a?(Hash)

      Array(document['blocks']).each do |block|
        next unless block['type'] == 'header'

        data = block['data'] ||= {}
        text = data['text']
        next unless needs_repair?(text)

        data['text'] = plain_text(text)
      end

      document
    end

    def draftjs_block_has_bold_header?(block)
      return false unless block.is_a?(Hash)
      return false unless block['type'].to_s.start_with?('header')

      Array(block['inlineStyleRanges']).any? { |range| range['style'] == 'BOLD' }
    end

    def draftjs_has_bold_headers?(draft)
      return false unless draft.is_a?(Hash)

      Array(draft['blocks']).any? { |block| draftjs_block_has_bold_header?(block) }
    end
  end
end

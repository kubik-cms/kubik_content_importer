# frozen_string_literal: true

require 'cgi'

module KubikContentImporter
  # Converts Draft.js inline styles and entities to HTML for Editor.js paragraph/header text.
  module DraftjsInlineHtml
    STYLE_OPEN = {
      'BOLD' => '<strong>',
      'ITALIC' => '<em>'
    }.freeze
    STYLE_CLOSE = {
      'BOLD' => '</strong>',
      'ITALIC' => '</em>'
    }.freeze

    CTA_LINK_CLASSES = 'button button--arrow button--arrow--right button--primary'

    module_function

    STYLE_ORDER = %w[BOLD ITALIC].freeze

    def convert(block, entity_map = {})
      text = block['text'].to_s
      return '' if text.blank?

      inline_styles = Array(block['inlineStyleRanges'])
      entity_ranges = Array(block['entityRanges'])
      return CGI.escapeHTML(text) if inline_styles.empty? && entity_ranges.empty?

      html = +''
      open_tags = []

      each_utf16_char(text) do |char, utf16_index|
        desired = tags_at(utf16_index, inline_styles, entity_ranges, entity_map)
        html << swap_open_tags(open_tags, desired)
        html << CGI.escapeHTML(char)
      end

      html << swap_open_tags(open_tags, [])
      html
    end

    # Draft.js offsets count UTF-16 code units, not Unicode characters.
    def each_utf16_char(text)
      index = 0
      text.each_char do |char|
        yield char, index
        index += char.encode('UTF-16LE').bytesize / 2
      end
    end

    def tags_at(index, inline_styles, entity_ranges, entity_map)
      active = inline_styles.each_with_object([]) do |range, styles|
        offset = range['offset'].to_i
        length = range['length'].to_i
        style = range['style'].to_s
        next unless index >= offset && index < offset + length
        next if STYLE_OPEN[style].blank?
        next if styles.include?(style)

        styles << style
      end

      tags = []
      STYLE_ORDER.each do |style|
        next unless active.include?(style)

        tags << [STYLE_OPEN[style], STYLE_CLOSE[style]]
      end

      entity_range = entity_ranges.find do |range|
        offset = range['offset'].to_i
        length = range['length'].to_i
        index >= offset && index < offset + length
      end
      if entity_range
        key = entity_range['key']
        entity = entity_map[key] || entity_map[key.to_s]
        if entity
          open_tag = entity_open_tag(entity)
          close_tag = entity_close_tag(entity)
          tags << [open_tag, close_tag] if open_tag.present? && close_tag.present?
        end
      end

      tags
    end

    def swap_open_tags(open_tags, desired)
      common = 0
      limit = [open_tags.length, desired.length].min
      while common < limit && open_tags[common] == desired[common]
        common += 1
      end

      html = +''
      open_tags[common..]&.reverse_each { |(_open, close)| html << close }
      desired[common..]&.each { |(open, _close)| html << open }
      open_tags.replace(desired)
      html
    end

    def entity_open_tag(entity)
      type = entity['type'].to_s
      data = entity['data'] || {}

      case type
      when 'LINK'
        url = data['url'].to_s
        return '' if url.blank?

        %(<a href="#{CGI.escapeHTML(url)}">)
      when 'CTA_LINK'
        url = data['url'].to_s
        return '' if url.blank?

        %(<a class="#{CTA_LINK_CLASSES}" href="#{CGI.escapeHTML(url)}">)
      when 'PDF_LINK'
        url = data['url'].to_s
        return '' if url.blank?

        %(<a class="link" href="#{CGI.escapeHTML(url)}" target="_blank" rel="noopener">)
      else
        ''
      end
    end

    def entity_close_tag(entity)
      type = entity['type'].to_s
      %w[LINK CTA_LINK PDF_LINK].include?(type) ? '</a>' : ''
    end
  end
end

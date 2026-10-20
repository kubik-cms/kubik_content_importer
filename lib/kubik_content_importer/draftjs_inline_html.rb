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

    module_function

    def convert(block, entity_map = {})
      text = block['text'].to_s
      return '' if text.blank?

      inline_styles = block['inlineStyleRanges'] || []
      entity_ranges = block['entityRanges'] || []
      return CGI.escapeHTML(text) if inline_styles.empty? && entity_ranges.empty?

      markers = []
      inline_styles.each do |range|
        offset = range['offset'].to_i
        length = range['length'].to_i
        style = range['style'].to_s
        next if STYLE_OPEN[style].blank?

        markers << { pos: offset, kind: :open, style: style }
        markers << { pos: offset + length, kind: :close, style: style }
      end

      entity_ranges.each do |range|
        offset = range['offset'].to_i
        length = range['length'].to_i
        key = range['key']
        entity = entity_map[key] || entity_map[key.to_s]
        next if entity.blank?

        markers << { pos: offset, kind: :entity_open, entity: entity }
        markers << { pos: offset + length, kind: :entity_close, entity: entity }
      end

      markers.sort_by! { |m| [m[:pos], marker_sort_order(m)] }

      html = +''
      open_styles = []
      open_entities = []
      cursor = 0

      markers.each do |marker|
        if marker[:pos] > cursor
          html << CGI.escapeHTML(text[cursor...marker[:pos]])
          cursor = marker[:pos]
        end

        case marker[:kind]
        when :open
          html << STYLE_OPEN[marker[:style]]
          open_styles << marker[:style]
        when :close
          style = open_styles.pop
          html << STYLE_CLOSE[style] if style
        when :entity_open
          tag = entity_open_tag(marker[:entity])
          html << tag if tag
          open_entities << marker[:entity]
        when :entity_close
          entity = open_entities.pop
          html << entity_close_tag(entity) if entity
        end
      end

      html << CGI.escapeHTML(text[cursor..]) if cursor < text.length
      html
    end

    def marker_sort_order(marker)
      case marker[:kind]
      when :close, :entity_close then 1
      else 0
      end
    end

    def entity_open_tag(entity)
      type = entity['type'].to_s
      data = entity['data'] || {}

      case type
      when 'LINK'
        url = data['url'].to_s
        return '' if url.blank?

        %(<a href="#{CGI.escapeHTML(url)}">)
      else
        ''
      end
    end

    def entity_close_tag(entity)
      type = entity['type'].to_s
      type == 'LINK' ? '</a>' : ''
    end
  end
end

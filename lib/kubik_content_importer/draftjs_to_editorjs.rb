# frozen_string_literal: true

require 'cgi'

module KubikContentImporter
  module DraftjsToEditorjs
    module_function

    def convert(draft)
      blocks = draft['blocks'] || []
      entity_map = draft['entityMap'] || {}
      editor_blocks = []
      index = 0

      while index < blocks.length
        block = blocks[index]
        type = block['type']

        if %w[unordered-list-item ordered-list-item].include?(type)
          # "unordered-list-item" contains the substring "ordered", so match the type exactly.
          style = type == 'ordered-list-item' ? 'ordered' : 'unordered'
          items = []
          while index < blocks.length && blocks[index]['type'] == type
            items << DraftjsInlineHtml.convert(blocks[index], entity_map)
            index += 1
          end
          editor_blocks << list_block(style, items)
        else
          editor_blocks.concat(wrap_blocks(map_block(block, entity_map)))
          index += 1
        end
      end

      {
        'time' => Time.now.to_i,
        'blocks' => editor_blocks.reject { |b| empty_paragraph?(b) },
        'version' => '2.28.0'
      }
    end

    def map_block(block, entity_map)
      type = block['type']
      text = DraftjsInlineHtml.convert(block, entity_map)

      case type
      when 'header-one' then header_block(text, 1)
      when 'header-two' then header_block(text, 2)
      when 'header-three' then header_block(text, 3)
      when 'header-four' then header_block(text, 4)
      when 'header-five' then header_block(text, 5)
      when 'header-six' then header_block(text, 6)
      when 'blockquote' then quote_block(text, '')
      when 'atomic' then map_atomic_block(block)
      when 'unstyled'
        paragraph_block(text)
      else
        paragraph_block(text.presence || block['text'].to_s)
      end
    end

    def map_atomic_block(block)
      data = block['data'] || {}
      atomic_type = data['type'].to_s

      case atomic_type
      when 'video'
        [media_block(video_media_item(data))]
      when 'image'
        item = image_media_item(data)
        item ? [media_block(item)] : []
      when 'blockquote'
        quote = data['blockquote'] || {}
        [quote_block(quote['quote_text'].to_s, quote['quote_cite'].to_s)]
      when 'download'
        [downloads_block(data)]
      when 'accordion'
        [accordion_block(data)]
      when 'table_plugin'
        [table_block(data)]
      when 'banner'
        [banner_block(data)]
      else
        paragraph_block("[#{atomic_type.presence || 'embedded'} content]")
      end
    end

    def video_media_item(data)
      youtube = data['youtube'].to_s.strip
      vimeo = data['vimeo'].to_s.strip
      src = data['src'].to_s.strip
      display = data['display'].to_s
      poster = data['poster'].to_s.strip.presence
      captions = data['captions'].to_s.strip.presence
      captions_scots = data['captions_scots'].to_s.strip.presence
      description = data['description'].to_s.strip.presence

      provider, url = video_provider_and_url(youtube: youtube, vimeo: vimeo, src: src, display: display)

      {
        'media_type' => 'video',
        'video_provider' => provider,
        'video_url' => url,
        'video_poster_url' => poster,
        'video_captions_url' => captions,
        'video_captions_scots_url' => captions_scots,
        'caption' => description,
        'layout' => 'default'
      }
    end

    def video_provider_and_url(youtube:, vimeo:, src:, display:)
      if youtube.present?
        ['youtube', youtube]
      elsif vimeo.present?
        ['vimeo', vimeo]
      elsif src.match?(%r{\.m3u8(\?|$)}i)
        ['stream', src]
      elsif display == 'hosted' || src.match?(/\.(mp4|webm|mov)(\?|$)/i)
        ['url', src]
      elsif src.present?
        ['url', src]
      else
        ['url', '']
      end
    end

    def image_media_item(data)
      image = data['image'] || {}
      legacy_id = image['id']
      kubik_id = MediaIdMap.kubik_id_for(legacy_id) || legacy_id
      return nil if kubik_id.blank?

      additional = image['additional_info'] || {}
      alt = additional['alt_text'].presence || additional[:alt_text].presence

      {
        'media_type' => 'image',
        'media' => { 'id' => kubik_id },
        'alt_text' => alt,
        'layout' => image_layout(data['display'])
      }
    end

    def image_layout(display)
      display.to_s.include?('800') || display.to_s.include?('1200') ? 'full-width' : 'default'
    end

    def downloads_block(data)
      repeated_items = Array(data['downloads']).filter_map do |dl|
        path = dl['path'].presence
        link_text = dl['link_text'].presence || dl['name'].presence
        row = { 'link_text' => link_text }
        legacy_file_id = dl['file_id']
        kubik_id = legacy_file_id.present? ? MediaIdMap.kubik_id_for(legacy_file_id) || legacy_file_id : nil
        if kubik_id.present?
          row['file'] = { 'id' => kubik_id }
        elsif path.blank?
          next
        end
        row
      end

      {
        'type' => 'downloads',
        'data' => {
          'section_title' => data['section_title'],
          'content' => { 'title' => data['section_title'].to_s },
          'files' => { 'repeated_items' => repeated_items },
          'downloads' => data['downloads'] || []
        }
      }
    end

    def accordion_block(data)
      accordion = data['accordion'] || {}
      tabs = Array(accordion['tabs']).sort_by { |tab| tab['position'].to_i }
      repeated_items = tabs.map do |tab|
        {
          'title' => tab['title'],
          'description' => tab['description']
        }
      end

      {
        'type' => 'accordion',
        'data' => {
          'items' => { 'repeated_items' => repeated_items },
          'content' => { 'title' => '', 'intro' => '', 'link' => '', 'link_text' => '' },
          'settings' => { 'layout' => 'no-images', 'divider' => 'bottom' }
        }
      }
    end

    def table_block(data)
      {
        'type' => 'table',
        'data' => {
          'rows' => data['rows'] || [],
          'source' => data['source'],
          'headerStyle' => data['headerStyle'] || {}
        }
      }
    end

    def banner_block(data)
      banner = data['banner'] || {}
      banner_id = banner['id']
      {
        'type' => 'banner',
        'data' => {
          'banner' => {
            'banner' => { 'id' => banner_id }
          },
          'content' => { 'banner_id' => banner_id }
        }
      }
    end

    def media_block(repeated_item)
      {
        'type' => 'media',
        'data' => {
          'content' => { 'title' => '', 'intro' => '', 'link' => '', 'link_text' => '' },
          'settings' => { 'divider' => 'bottom' },
          'media' => { 'repeated_items' => [repeated_item] }
        }
      }
    end

    def header_block(text, level)
      {
        'type' => 'header',
        'data' => {
          'text' => EditorjsHeaderText.plain_text(text),
          'level' => level
        }
      }
    end

    def paragraph_block(text)
      { 'type' => 'paragraph', 'data' => { 'text' => text } }
    end

    def quote_block(text, caption)
      {
        'type' => 'quote',
        'data' => {
          'text' => text,
          'caption' => caption,
          'alignment' => 'left'
        }
      }
    end

    def list_block(style, items)
      {
        'type' => 'nested_list',
        'data' => {
          'style' => style,
          'items' => EditorjsNestedList.normalize_items(items)
        }
      }
    end

    def empty_paragraph?(block)
      block['type'] == 'paragraph' && block.dig('data', 'text').to_s.strip.blank?
    end

    def wrap_blocks(mapped)
      case mapped
      when Array then mapped.compact
      when Hash then [mapped]
      else []
      end
    end
  end
end

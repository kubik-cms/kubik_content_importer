# frozen_string_literal: true

module KubikContentImporter
  # Kubik admin uses @editorjs/nested-list (block type nested_list), not the classic list tool.
  module EditorjsNestedList
    module_function

    def normalize_document(document)
      doc = document.deep_dup
      blocks = doc['blocks']
      return doc unless blocks.is_a?(Array)

      blocks.each do |block|
        next unless block.is_a?(Hash)

        type = block['type'].to_s
        data = block['data']
        next unless data.is_a?(Hash)

        if type == 'list'
          block['type'] = 'nested_list'
          data['items'] = normalize_items(data['items'])
        elsif type == 'nested_list'
          data['items'] = normalize_items(data['items'])
        end
      end

      doc
    end

    def normalize_items(items)
      Array(items).map { |item| normalize_item(item) }
    end

    def normalize_item(item)
      case item
      when String
        { 'content' => item, 'items' => [] }
      when Hash
        h = item.stringify_keys
        {
          'content' => h['content'].presence || h['text'].to_s,
          'items' => normalize_items(h['items'])
        }
      else
        { 'content' => item.to_s, 'items' => [] }
      end
    end
  end
end

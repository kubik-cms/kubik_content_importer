# frozen_string_literal: true

module KubikContentImporter
  # Normalizes legacy Draft.js JSON (or plain text) into Editor.js JSON for Kubik WYSIWYG.
  module WysiwygPayload
    module_function

    def normalize(raw)
      return '' if raw.blank?

      if raw.is_a?(String) && editorjs_json?(raw)
        return finalize_editorjs(JSON.parse(raw))
      end

      if raw.is_a?(Hash)
        return finalize_editorjs(raw) if editorjs_hash?(raw)

        return finalize_editorjs(DraftjsToEditorjs.convert(raw))
      end

      parsed = JSON.parse(raw)
      return finalize_editorjs(parsed) if editorjs_hash?(parsed)

      finalize_editorjs(DraftjsToEditorjs.convert(parsed))
    rescue JSON::ParserError
      finalize_editorjs(editorjs_paragraph(raw.to_s))
    end

    def finalize_editorjs(document)
      doc = document.deep_dup
      EditorjsHeaderText.normalize_document!(doc)
      EditorjsNestedList.normalize_document(doc).to_json
    end

    def editorjs_json?(string)
      editorjs_hash?(JSON.parse(string))
    rescue JSON::ParserError
      false
    end

    def draftjs_hash?(payload)
      return false unless payload.is_a?(Hash) && payload['blocks'].is_a?(Array)

      payload.key?('entityMap') ||
        payload['blocks'].any? { |block| block.is_a?(Hash) && block.key?('key') }
    end

    def editorjs_hash?(payload)
      return false unless payload.is_a?(Hash) && payload['blocks'].is_a?(Array)
      return false if draftjs_hash?(payload)

      payload['version'].present? ||
        payload['blocks'].all? { |block| block.is_a?(Hash) && block.key?('data') && !block.key?('key') }
    end

    def editorjs_paragraph(text)
      {
        'time' => Time.now.to_i,
        'blocks' => [{ 'type' => 'paragraph', 'data' => { 'text' => text } }],
        'version' => '2.28.0'
      }
    end
  end
end

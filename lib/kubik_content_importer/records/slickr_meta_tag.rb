# frozen_string_literal: true

module KubikContentImporter
  module Records
    class SlickrMetaTag < ActiveRecord::Base
      self.table_name = 'slickr_meta_tags'
    end
  end
end

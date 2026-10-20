# frozen_string_literal: true

module KubikContentImporter
  module Records
    class SlickrMediaUpload < ActiveRecord::Base
      self.table_name = 'slickr_media_uploads'
    end
  end
end

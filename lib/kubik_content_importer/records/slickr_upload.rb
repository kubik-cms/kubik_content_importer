# frozen_string_literal: true

module KubikContentImporter
  module Records
    class SlickrUpload < ActiveRecord::Base
      self.table_name = 'slickr_uploads'
    end
  end
end

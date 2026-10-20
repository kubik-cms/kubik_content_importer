# frozen_string_literal: true

module KubikContentImporter
  module Records
    class SlickrNavigation < ApplicationRecord
      self.table_name = 'slickr_navigations'

      SLICKR_MASTER_ID = 1
    end
  end
end

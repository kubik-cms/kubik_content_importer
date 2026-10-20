# frozen_string_literal: true

module KubikContentImporter
  class Engine < ::Rails::Engine
    isolate_namespace KubikContentImporter

    rake_tasks do
      load 'kubik_content_importer/tasks.rake'
    end
  end
end

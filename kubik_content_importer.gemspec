# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'kubik_content_importer'
  spec.version = '0.1.0'
  spec.authors = ['Primate']
  spec.email = ['admin@primate.co.uk']
  spec.summary = 'Configurable CMS content importer (Slickr → Kubik)'
  spec.required_ruby_version = '>= 3.2.0'

  spec.files = Dir.chdir(__dir__) { Dir['lib/**/*', 'README.md'] }
  spec.require_paths = ['lib']

  spec.add_dependency 'activesupport', '>= 7.0'
  spec.add_dependency 'railties', '>= 7.0'
end

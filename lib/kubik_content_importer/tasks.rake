# frozen_string_literal: true

namespace :kubik_content_importer do
  desc 'Import CMS content from legacy Slickr tables (IMPORTER_DRY_RUN=1, IMPORTER_ONLY=pages)'
  task run: :environment do
    dry = ENV['IMPORTER_DRY_RUN'].present?
    only = ENV['IMPORTER_ONLY']&.split(',')&.map(&:strip)
    KubikContentImporter.run!(only: only, dry_run: dry)
  end

  desc 'Copy slickr_media_uploads → kubik_media_uploads (same ids; IMPORTER_DRY_RUN=1)'
  task import_media: :environment do
    dry = ENV['IMPORTER_DRY_RUN'].present?
    KubikContentImporter.run!(only: %i[media_uploads meta_tags upload_reflections], dry_run: dry)
  end

  desc 'Fill kubik_meta_tags OG/Twitter fields from SEO columns (IMPORTER_DRY_RUN=1)'
  task backfill_meta_social: :environment do
    dry = ENV['IMPORTER_DRY_RUN'].present?
    abort 'Kubik::Metatagable::SocialMetaBackfill is not available' unless defined?(Kubik::Metatagable::SocialMetaBackfill)

    result = Kubik::Metatagable::SocialMetaBackfill.backfill!(dry_run: dry)
    puts "backfill_meta_social #{dry ? '(dry run)' : ''} updated=#{result[:updated]} skipped=#{result[:skipped]}"
  end

  desc 'Copy slickr_navigations → kubik_navigation_items (same ids; IMPORTER_DRY_RUN=1)'
  task import_navigation: :environment do
    dry = ENV['IMPORTER_DRY_RUN'].present?
    KubikContentImporter.run!(only: %i[navigation], dry_run: dry)
  end

  desc 'Compare Slickr vs Kubik navigation row counts'
  task verify_navigation: :environment do
    require 'kubik_content_importer/records/slickr_navigation'
    slickr_count = KubikContentImporter::Records::SlickrNavigation.where.not(id: 1).count
    kubik_count = Kubik::NavigationItem.count
    roots = Kubik::NavigationItem.roots.pluck(:title)

    puts "slickr_navigations (excl. master): #{slickr_count}"
    puts "kubik_navigation_items:         #{kubik_count}"
    puts "kubik roots: #{roots.join(', ')}"

    ok = kubik_count >= slickr_count
    abort 'verify_navigation failed' unless ok
    puts 'verify_navigation OK'
  end

  desc 'Compare Slickr vs Kubik media row counts'
  task verify_media: :environment do
    require 'kubik_content_importer/records/slickr_media_upload'
    slickr_count = KubikContentImporter::Records::SlickrMediaUpload.count
    kubik_count = Kubik::MediaUpload.count
    legacy_linked = Kubik::MediaUpload.where(
      "additional_info ->> ? IS NOT NULL",
      KubikContentImporter::MediaIdMap::LEGACY_KEY
    ).count
    reflections = Kubik::Upload.count

    puts "slickr_media_uploads: #{slickr_count}"
    puts "kubik_media_uploads:  #{kubik_count}"
    puts "kubik_media_uploads (legacy_slickr link): #{legacy_linked}"
    puts "kubik_uploads:        #{reflections}"

    ok = kubik_count >= slickr_count && legacy_linked >= slickr_count
    abort 'verify_media failed' unless ok
    puts 'verify_media OK'
  end
end

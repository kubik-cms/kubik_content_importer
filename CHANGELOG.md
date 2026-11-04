## [Unreleased]

## [0.1.1] - 2026-11-04

### Added

- `KubikContentImporter::EditorjsHeaderText` to normalize Draft.js bold markup on migrated header blocks.
- Rake task hooks for bulk WYSIWYG header repair workflows.

### Changed

- Draft.js inline HTML and Editor.js conversion preserve headings and lists more reliably.
- `WysiwygPayload` normalization upgrades legacy list blocks when re-saving content.
- Kubik meta tag and navigation import targets handle Reading Schools–style legacy fields.

## [0.1.0] - 2026-10-01

- Initial import from host-app vendor; Slickr → Kubik content migration framework.

# Changelog

All notable changes to this package are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the package follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking

- **Breaking:** `FlowPresentationError` gained `.dismissedByUser`. A pending `present` now throws it (or `CancellationError`) where it used to wait forever; add the case to exhaustive switches.

### Added

- Navigation transition catalogue
- Pattern-based universal-link registry
- Type-safe path builder + navigation state restoration

### Changed

- Anvyx* module (split from Application)

### Fixed

- Pending flow steps end on dismissal and task cancellation

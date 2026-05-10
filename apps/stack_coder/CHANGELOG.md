# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic
Versioning where practical for published artifacts.

## [Unreleased]

### Added

- Regex-free authority guard and readback redaction for local Profile B task
  dispatch, covering unmanaged env-sourced provider keys, base URLs, auth
  roots, tool permissions, target refs, and workspace secrets.
- Non-umbrella workspace structure with reusable core packages, built-in site
  package, and runnable daemon, CLI, and TUI apps.
- Workbench node IR, reusable widgets, and BEAM-native TUI runtime over
  `ex_ratatui`.

### Changed

- Refreshed the workspace README, guide set, and HexDocs navigation to describe
  the delivered architecture in present tense.

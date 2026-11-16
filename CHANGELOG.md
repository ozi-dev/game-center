# Changelog

## 2.2.0 — 2026-11-16

- Rename the project to SofaRelay; use Installer.exe, SofaRelay.exe and START-HERE.txt.
- Standardize Start menu entries as SofaRelay, SofaRelay Settings and Restore Display in every UI language; new installs default to English.
- Preserve existing installation directories, extension IDs, playtime state and emulator profiles; support old settings locations, command placeholders and launcher shortcuts.
- Refresh all four language catalogs, documentation, screenshots, posters, release packaging and repository links.
- Add upgrade and shortcut regression checks; fix Playnite version detection for native 1.0 bootstrapper executables.


- Redesign the GitHub presentation with localized banners, download buttons, prominent real-library GIFs, an illustrated setup flow and expandable technical details.
- Consolidate translated READMEs under `docs/readme` and move the extended offline manual into `docs/guides`; update build, packaging, funding and link checks for the layout.


## 2.1.0 — 2026-11-16

- Add English, Turkish, French and Spanish to the installer, settings dialogs, worker messages and companion menus, with a persistent language selector.
- Preserve paths and preferences when changing language; apply the matching Playnite language without duplicating managed filter presets or Sunshine tiles.
- Add offline guides, localized wizard screenshots, and real connected-library screenshots/navigation GIFs in all four languages.
- Add 1,941 localization assertions to the standard build and exclude stale generated binaries from packaged source.

## 2.0.0 — first public release

- Guided Playnite / Sunshine / Moonlight setup with optional signed virtual display and controller driver.
- Store connections, supported Epic direct downloads and selected-game Steam install confirmation.
- Fritchii/Lichii-compatible playtime import, RetroArch runtime history and overlap-aware merging.
- Missing NUP/sidecar cover handling; controller, keyboard and mouse settings.
- Configurable display resolution/refresh rate, physical-monitor signal off, restoration and two Moonlight launch tiles.
- Settings backups, conflict-aware restore, display recovery and redacted diagnostics.
- Optional Shield/Android TV ADB checks and guided account/PIN setup.
- English, Turkish, French and Spanish project documentation; actual UI remains Turkish.
- Public source, tests, clean screenshots, upstream credits and funding-link setup helper.

Validation and hardware limits are recorded in [TESTING.md](docs/TESTING.md).

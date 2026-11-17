# Changelog

## 2.3.2 — 2026-11-17 (public beta)

- Keep physical monitors enabled by default on fresh installations; preserve existing explicit monitor-off choices.
- Display a public-beta notice in all four wizard languages and documentation entry points.
- Publish tagged builds as pre-releases rather than automatically marking them stable. Record the remaining clean-install, reboot/sign-in, multi-client and removal checks before stable promotion.
- Direct downloads to the release list so pre-release classification cannot silently send users back to an older stable package.
- Add regression checks for the monitor-on default, preserved opt-in and real configuration branches. Known display identity/client-state fixes from 2.3.1 remain included.

## 2.3.1 — 2026-11-17

- Restore display snapshots by stable monitor paths and current adapter/source/target identities. Pre-reboot snapshots no longer replay invalid session IDs; disconnected monitors are rejected instead of selecting another output.
- Force and persist the repaired physical display mode while preserving the saved resolution, refresh rate and primary layout.
- Distinguish actual streaming clients from a paused application retained for resume. Display recovery no longer stays blocked by `/serverinfo` reporting BUSY after the last client disconnects.
- Keep pending connections and multiple clients protected; missing/truncated/current-process log uncertainty postpones recovery.
- Add 11 pure display-rebinding assertions and four stream-lifecycle Pester regressions. Existing core, backend, privacy and four-language checks remain enabled.

## 2.3.0 — 2026-11-16

- Replace elevated user-folder scripts with an embedded, hash-bound broker and protected Program Files code / ProgramData machine state; validate request ownership and exact restore targets.
- Separate normal-user restore/settings from protected restore. Reject legacy mutable privileged journals and unprotected component directories.
- Add ownership-aware integration removal, preserving shared applications, games and driver-store packages; report manual cleanup steps.
- Pin reviewed Authenticode certificate identities; clean partial downloads and record library-update failures.
- Add optional unelevated sign-in display recovery, LAN-only Sunshine/firewall controls and caught-error configuration/task/firewall rollback.
- Centralize VERSION; use a pinned deterministic compiler and fixed ZIP timestamps. Build/test tagged releases in Windows 2022/2025 CI, publish SHA-256 checksums and GitHub build-provenance attestations.
- Split worker operations, add security-focused PowerShell analysis, Pester/privacy/tamper/broker-boundary tests, link checks and weekly upstream review.
- Expand four-language setup/help with verification, troubleshooting, removal, trust boundaries and explicit hardware/signing test limits.

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

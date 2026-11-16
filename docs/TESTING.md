# Validation for 2.2.0

Validated on Windows 11 x64, PowerShell 5.1, .NET Framework 4.8 and Playnite 10.64.

- 20 core assertions: historical import, overlapping sessions counted once, separate direct sessions, repeated synchronization, source counter reset, binary record parsing, incomplete writes, title ID matching, RetroArch aggregate/per-core transition, Shield mode validation.
- 55 backend assertions: atomic file writes, original backups and applied hashes, path/ZIP traversal rejection, Windows argument quoting, configuration preservation, provider selection and correct IDs, authentication-field preservation, installed/portable Playnite data paths, all pinned component records, real configuration functions exercised against isolated fixtures, custom VDD modes, repeat apply without duplicate apps/modes, restore conflict preflight and original settings restoration.
- 1,950 localization assertions: all four 241-string catalogs, nonempty translations, format-placeholder parity, language normalization, translated validation, argument preservation and settings persistence.
- Separate worker processes rejected invalid settings with the expected translated validation message in all four languages, before creating an installation directory.
- WinForms seven-page navigation and settings binding and four-language switching self-test; all seven pages rendered, with sample layouts visually inspected during development.
- Actual fresh Playnite extraction and native extension loading from a folder containing spaces. Native emulator registration, automatic scanner import and a synthetic 1,234-second playtime record succeeded. Restart and repeated setup preserved the same game/profile and duration. No actual game was launched for these tests.
- Existing installation migration reused the existing emulator profile/scanner IDs, preserved cumulative playtime and enabled the mouse cursor.
- Release is assembled from an explicit allowlist. Personal paths, device IDs, user data directories, game databases, credentials, ROMs, keys and saves are rejected. ZIP contents and per-file SHA-256 values are checked after extraction.

Hardware and accounts still require a first-use check on the receiving computer. A clean Windows VM, physical Shield playback, HDMI high-refresh output, new Sunshine/ViGEm/VDD installation and ADB authorization were not tested on the friend's hardware. System/driver/service boundaries in protected configuration tests are mocked; existing local Sunshine streaming settings were not changed for those tests. Store UI revisions may require the documented controller-mouse fallback.

To reproduce the code checks, use separate PowerShell processes (loading a DLL locks it for that process):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1 -PlayniteSdkPath "D:\Playnite\Playnite.SDK.dll"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\BackendTests.ps1
.\build\SofaRelay.exe --selftest
```

`tests/Prepare-Smoke.ps1` creates a synthetic scanner fixture under `reports`; its executable is a placeholder and its fake ROM must never be launched. Advanced `Worker.ps1 -Action CoreOnly -NoShortcuts` isolates the Playnite installation stage from system changes.

Documentation media: all seven wizard pages were captured in each of the four languages with example paths. Fullscreen store/emulator screenshots and navigation GIFs were captured from the maintainer’s real connected library in each native Playnite language, without launching games. Game/library databases and account data are not included in the package.

Upgrade regression coverage checks legacy settings discovery without moving installation folders; stable English Start menu targets and the recovery hotkey; backup and retirement of owned old shortcuts while preserving unrelated ones; old/new emulator-root placeholders; and Playnite version detection from its actual managed assembly instead of the native bootstrapper?s 1.0 file metadata.

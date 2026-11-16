# Build and maintain

## Requirements

- Intel/AMD x64 Windows with .NET Framework 4.8, Windows PowerShell 5.1 and Git.
- A clean Playnite 10.64+ distribution providing `Playnite.SDK.dll`.
- Python 3.11+ for optional manifest verification and publication checks. The application itself does not require Python.

## Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1 -PlayniteSdkPath "D:\Playnite\Playnite.SDK.dll"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\BackendTests.ps1
.\build\OyunMerkezi.exe --selftest
```

Use separate processes: loading a .NET assembly locks it for that PowerShell process. The build uses the C# compiler included with .NET Framework; no Visual Studio installation or NuGet restore is needed.

`Build.ps1` compiles the core, WinForms wizard, Playnite companion plugin and Steam helper. Output goes to `build`. `Package.ps1` creates the redistributable ZIP and SHA-256 list from a deliberate allowlist. It refuses to overwrite an existing release ZIP. Move a previous local artifact aside before creating a new candidate.

## Source map

| Path | Purpose |
| --- | --- |
| `src/Core.cs` | Settings schema, emulator time parsing, merge rules and validation |
| `src/App.cs` | Setup and maintenance GUI |
| `src/Plugin.cs`, `src/Artwork.cs` | Playnite events, history sync, covers and settings access |
| `src/SteamTvInstall.cs` | Selected-game Steam dialog confirmation |
| `scripts/Worker.ps1`, `Common.psm1` | Setup actions, downloads, backups and diagnostics |
| `scripts/NativeSetup.psm1` | Playnite emulator/scanner/filter configuration |
| `assets/native` | Windows display snapshot/restore and signed-driver installation helpers |
| `manifests/packages.json` | Pinned official download URLs and SHA-256 values |
| `tests` | Core/backend assertions and synthetic smoke-test preparation |
| `docs` | Guides, public screenshots, credits and testing scope |

## Before publishing

Run `python scripts/maintainer/CheckPublic.py` after staging. It checks the public file list, private-path/token patterns, local documentation links and language navigation. Never add an installed Playnite library, emulator data directory, credentials, device keys, ROMs or personal logs. The root `.gitignore` is an allowlist.

Pin upstream URLs and hashes deliberately. `scripts/PrepareManifests.py` verifies existing entries; it does not bless changed files or replace hashes automatically. Keep license notices and corresponding 7-Zip source with the extractor.

For a release: build, run tests, package, check every ZIP file against `SHA256SUMS.txt`, upload the ZIP and its `.sha256` companion to GitHub Releases. Source builds omit generated `assets/plugin/*.dll` and `*.exe` from Git; the build produces them.

## Localization

Current user-facing documentation is in `README*.md` and `docs/guides/{en,tr,fr,es}.md`. Keep technical limitations consistent across translations. The setup UI and backend messages remain Turkish in 2.0.0. Contributions toward an actual resource-based installer translation are welcome; do not present translated documentation as a translated executable.

## Safe screenshots

Use `OyunMerkezi.exe --preview <folder> --config <example-settings.json>` with example paths and no accounts. This renders the seven real wizard pages without running diagnosis, installing components or opening games. Never publish desktop notifications, account identifiers or pairing codes.

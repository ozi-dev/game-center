# Build and maintain

## Requirements

- Intel/AMD x64 Windows with .NET Framework 4.8, Windows PowerShell 5.1 and Git.
- A clean Playnite 10.64+ distribution providing `Playnite.SDK.dll`.
- Python 3.11+ for optional manifest verification and publication checks. The application itself does not require Python.

## Build

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1 -PlayniteSdkPath "D:\Playnite\Playnite.SDK.dll"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\BackendTests.ps1
.\build\SofaRelay.exe --selftest
```

Use separate processes: loading a .NET assembly locks it for that PowerShell process. The build uses the C# compiler included with .NET Framework; no Visual Studio installation or NuGet restore is needed.

`Build.ps1` compiles the core, WinForms wizard, Playnite companion plugin and Steam helper. Output goes to `build`. `Package.ps1` creates the redistributable ZIP and SHA-256 list from a deliberate allowlist. It refuses to overwrite an existing release ZIP. Move a previous local artifact aside before creating a new candidate.

## Source map

| Path | Purpose |
| --- | --- |
| `src/Core.cs` | Settings schema, emulator time parsing, merge rules and validation |
| `src/App.cs`, `src/LocalizedControls.cs` | Setup and maintenance GUI, live language switching |
| `src/Localization.cs`, `locales` | Four-language UI and worker catalogs |
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

Current user-facing documentation is in `README.md`, `docs/readme/{tr,fr,es}.md` and `docs/guides/{en,tr,fr,es}.md`. Keep technical limitations consistent across translations. The wizard and worker use `locales/{en,tr,fr,es}.json`, initialized by `src/Localization.cs`. Keep keys and format placeholders aligned with the Turkish source catalog. `Build.ps1` runs the localization assertions automatically. The visible selector saves `UILanguage`; language changes preserve user paths and toggles. Apply also selects the matching native Playnite language. Regenerate offline guides after editing Markdown: install the optional maintainer dependency with `python -m pip install Markdown`, then run `python scripts/maintainer/RenderGuides.py`. Python and Markdown are not runtime requirements.

## Safe screenshots

Use `SofaRelay.exe --preview <folder> --config <example-settings.json>` with example paths and no accounts. This renders the seven real wizard pages without running diagnosis, installing components or opening games. Never publish desktop notifications, account identifiers or pairing codes.

Real library screenshots require the library owner’s permission. Our public Playnite captures use the maintainer’s connected libraries; capture only the application, keep credentials and account screens private, and never launch games while recording documentation. The animated GIFs contain captured views rather than generated mockups.

The repository root keeps a single English README. Translated showcase pages live in `docs/readme`, guides and the extended Turkish manual in `docs/guides`. Presentation artwork in `docs/media` is editable SVG; screenshots remain real, unmodified Playnite captures. Keep local asset paths relative to each README’s directory.

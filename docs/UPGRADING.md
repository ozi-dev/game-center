# Upgrading to SofaRelay 2.2

SofaRelay is the new name for this project's earlier Game Center / Oyun Merkezi releases. Use **Installer.exe** for setup and **SofaRelay.exe** for settings. The Windows Start menu folder is **SofaRelay**, with **SofaRelay**, **SofaRelay Settings** and **Restore Display** shortcuts. These names are English in every UI language. A new installation starts in English; the English, Turkish, French and Spanish selector remains available.

Existing installation directories are reused. A directory called `OyunMerkezi` or `Oyun-Merkezi` does not need renaming, nor do Playnite, ROM, emulator-data or game-installation folders. Keep the old installation's `data/settings.json`; launch the new app from that installation or select that file with `--config`. Local-app-data settings from the previous default location are also discovered automatically.

The companion and setup extension IDs remain unchanged to preserve Playnite extension state and playtime. Existing extension directories, emulator profiles and scanners are reused. Historical merge-state files and game IDs are preserved. Old `{GameCenterDir}` arguments continue to resolve; new profiles use `{SofaRelayDir}`. `tools` is the new helper directory, with a fallback for the old `araclar` location.

When applying setup over an old installation, an existing `OyunMerkezi.exe` becomes a small compatibility launcher forwarding its arguments to `SofaRelay.exe`. This preserves existing shortcuts, including paths containing spaces. Fresh packages expose only the English executable names. Owned old Start menu shortcuts are backed up before replacement; unrelated shortcuts are left intact.

Close Playnite, the settings app and active streams before applying. Keep the whole extracted package together. Store sign-ins and existing game data are reused; the upgrade does not move games or emulator data. Existing Sunshine tiles are matched against their previous translated names so applying settings does not duplicate them.

The GitHub repository is now [ozi-dev/sofarelay](https://github.com/ozi-dev/sofarelay). Earlier repository URLs redirect; update Git remotes to the new address. Historical release archives retain their original filenames and checksums.

## Naming note

Apple uses **Game Center** for its gaming service: [Apple Games](https://games.apple.com/). The project adopted the more distinctive SofaRelay name after a preliminary public-web and GitHub name search on 16 November 2026. This was not a formal trademark clearance or a trademark registration. No affiliation with Apple or the upstream projects is implied.

[Setup guide](guides/en.md) · [Validation](TESTING.md) · [Credits](CREDITS.md)

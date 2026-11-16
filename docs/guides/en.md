# Install and use Game Center

[English](en.md) · [Türkçe](tr.md) · [Français](fr.md) · [Español](es.md) · [Project](../../README.md)

The 2.1.0 installer supports English, Turkish, French and Spanish. Choose **English** in the sidebar; the selection is saved and offline help follows it. Applying settings also selects English in Playnite.

## Before you begin

Use Intel/AMD x64 Windows 10/11 with .NET Framework 4.8, PowerShell 5.1 and a current GPU driver. The host needs a Sunshine-compatible encoder. Keep PC and client on the same network; Ethernet is preferable. Internet is required to download components.

Download the ZIP from [Releases](https://github.com/ozi-dev/game-center/releases/latest), extract everything, and open `Kurulum.exe`. Do not run it inside the ZIP or copy only the EXE. Existing Playnite installations and games can be reused. Nothing here supplies games, firmware, keys or store accounts.

## The seven pages

| Page | Label | What to do |
| --- | --- | --- |
| 1 | Welcome and checks | Wait for detection. Pick an installation folder. Leave Playnite blank to install it, or select its existing executable's folder. |
| 2 | Libraries and accounts | Select stores. Epic direct installation uses Legendary; native store clients can be installed as needed. |
| 3 | Emulators | Use `Add emulator`. Select EXE, ROM folder, platform/extensions and data directory. RetroArch needs a core DLL, one entry per system/core. |
| 4 | Streaming and display | Configure controls, desktop/library tiles, optional virtual display, physical-monitor signal off, restoration, resolution/Hz and client type. |
| 5 | Shield / TV connection | Follow Moonlight/Sunshine pairing. ADB is optional. |
| 6 | Setup and maintenance | Close Playnite and streams. `Install / complete setup` installs; `Apply settings / repair` applies/repairs. Approve elevation, then reboot if requested. |
| 7 | Help and recovery | Help, logs, display recovery and backup restoration. |

Use `Save settings` to persist your preferences. Host changes need Apply afterward. Bitrate and HDR preferences must also be selected in Moonlight; the setup tool cannot silently rewrite private client settings.

## Connect accounts

Open Playnite desktop from page 2. Main menu → Add-ons (F9) → Extension settings → Libraries → your provider → Authenticate. For direct Epic downloads choose **Legendary (Epic Games)**. Sign in in the provider's own UI; never send your password or two-factor code to the maintainer. Update all libraries with F5.

Steam's selected-game install helper may need Steam restarted with `-cef-force-accessibility`. Configure a default download library in Steam. EA/Ubisoft/Xbox, linked third-party games and first-run agreements can require a client confirmation. In Moonlight, hold the controller's Start button to toggle mouse mode; use the stick to move, A to left-click and B to right-click.

## Pair the TV / Shield

Install **Moonlight Game Streaming** from the client's app store. On the PC, open [Sunshine](https://localhost:47990), create a local administrator login on first use, and enter the PIN shown by Moonlight. If discovery fails, add the PC's IPv4 address manually in Moonlight.

Start with 1080p60 / 20 Mbps, then raise quality if the network is stable. Shield's 4K output is limited to 60 Hz; a high-refresh TV panel does not change that. Choose higher refresh rates only when the actual client supports the requested mode. Enable Moonlight's **Optimize game settings** for automatic display switching. Open **Game Library - Playnite** or **Desktop**.

## Emulator history and artwork

- Fritchii/Lichii-compatible data comes from `play_time\playtime.bin` in the emulator's user/data folder. NUP title IDs are read from the file; other supported files need a correct 16-digit ID in the filename or an explicit `TitleMappings` entry.
- RetroArch uses `.lrtl` runtime logs. Select the directory containing `retroarch.cfg`; old time cannot be imported if runtime logging was disabled. Choose the matching core and ROM extensions for each system.
- Other emulators can still have new Playnite-launched sessions tracked. Old-history import is limited to supported formats.
- Use `Game.cover.jpg` or `Game.cover.png` beside `Game.xci` for a sidecar cover. NUP extraction and Playnite metadata handle other supported artwork.

## Recovery and common issues

| Issue | Next step |
| --- | --- |
| Black screen / physical monitor stays off | End the stream; press **Ctrl+Alt+F11**, or Start → Oyun Merkezi → **Restore Display**. Win+P and Windows Display Settings are alternatives. |
| PC not found | Check Sunshine's service, the same LAN, private network/firewall permissions, and manual IPv4 entry. Local streaming needs no router port forwarding. |
| Requested refresh rate absent | Check the client output, decoder, cable and Moonlight FPS. Reboot after adding VDD modes if requested; refresh detection and reapply. |
| ADB unauthorized | Approve the RSA prompt on the TV. ADB is not needed for normal streaming. The optional tool targets IPv4:5555; devices using pairing-code ports need manual ADB pairing or the app-store route. |
| Playnite open / stream active | Close normally before Apply. The installer does not force-close games or interrupt a stream. |
| Restore refuses a changed file | Inspect `data/backups` and merge manually. Restoration deliberately preserves post-install edits. |
| Download hash fails / Windows warns about the EXE | Use the official release/checksums or compile from source. The custom app is unsigned. Do not disable security checks; third-party package hashes are enforced. |

Backups and settings are under the installed folder's `data` directory. Use Start → Oyun Merkezi → **Game Center Settings** afterward. The optional TOTK buttons only edit an already installed compatible local Dynamic FPS profile; use the emulator/mod's own documentation for compatibility.

[Full original Turkish manual](manual.tr.html) · [Testing limits](../TESTING.md) · [Credits](../CREDITS.md)

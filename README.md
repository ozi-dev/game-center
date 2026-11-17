<p align="center"><img src="docs/media/hero-en.svg" alt="SofaRelay — Your PC library deserves a bigger screen." width="100%"></p>

<p align="center"><strong>PUBLIC BETA</strong> · Hardware validation is ongoing. New installations keep the physical monitor on; monitor shutdown is opt-in.<br><a href="docs/RELEASE-STATUS.md">Tested scenarios and remaining checks</a></p>

<p align="center"><a href="README.md"><b>English</b></a> &nbsp; · &nbsp; <a href="docs/readme/tr.md">Türkçe</a> &nbsp; · &nbsp; <a href="docs/readme/fr.md">Français</a> &nbsp; · &nbsp; <a href="docs/readme/es.md">Español</a></p>

<h3 align="center">Your PC library deserves a bigger screen.</h3>
<p align="center">Bring your stores and emulators together. Pick up a controller. Make the TV your next place to play.</p>

<p align="center">
  <a href="https://github.com/ozi-dev/sofarelay/releases"><img src="docs/media/ui/download-en.svg" alt="Download for Windows" width="290" height="54"></a>
  &nbsp;
  <a href="docs/guides/en.md"><img src="docs/media/ui/guide-en.svg" alt="Setup guide" width="235" height="54"></a>
</p>

<p align="center">
  <a href="https://github.com/ozi-dev/sofarelay/releases"><img src="https://img.shields.io/badge/channel-public%20beta-ff793f?style=flat-square" alt="Public beta"></a>
  <a href="https://github.com/ozi-dev/sofarelay/actions/workflows/ci.yml"><img src="https://github.com/ozi-dev/sofarelay/actions/workflows/ci.yml/badge.svg" alt="Windows build and validation"></a>
  <a href="LICENSE.txt"><img src="https://img.shields.io/badge/license-MIT-52d4df?style=flat-square" alt="MIT license"></a>
</p>

<!-- SUPPORT-TOP:START -->
<p align="center"><a href="https://buymeacoffee.com/oziooztrk"><img src="docs/media/support/buy-me-a-coffee.png" alt="Support Ozi on Buy Me a Coffee" width="218" height="61"></a></p>
<!-- SUPPORT-TOP:END -->

<p align="center"><b>Steam &nbsp; / &nbsp; Epic &nbsp; / &nbsp; EA &nbsp; / &nbsp; Ubisoft &nbsp; / &nbsp; Xbox &nbsp; / &nbsp; Retro</b></p>

---

## See it in action

<a href="docs/screenshots/en/navigation.gif"><img src="docs/screenshots/en/navigation.gif" alt="See it in action — Steam, Epic, Fritchii, Playnite" width="100%"></a>

<p align="center"><sub>Playnite fullscreen · Steam / Epic / Fritchii · Sunshine + Moonlight</sub></p>

<p align="center">
  <img src="docs/media/flow-en-1.svg" alt="BRING YOUR GAMES — Stores + local emulators" width="260">
  <img src="docs/media/flow-en-2.svg" alt="MAKE IT YOURS — A guided setup. Your settings." width="260">
  <img src="docs/media/flow-en-3.svg" alt="TAKE THE COUCH — TV / Shield / Moonlight" width="260">
</p>

## Make yourself comfortable.

| Feature | What you get |
| :--- | :--- |
| **One place for your games** | Steam, Epic, EA, Ubisoft, optional Xbox and local/emulated games through Playnite integrations. |
| **Install from the couch** | Legendary handles supported Epic downloads. A helper confirms the selected Steam install. Other stores may need their client. |
| **Keep your history** | Import compatible Fritchii/Lichii playtime and RetroArch logs, with overlap handling. |
| **Pick your controls** | Controller, keyboard or mouse. A visible cursor in the library; game bindings stay in the emulator. |
| **Make the screen yours** | Library and desktop tiles, optional virtual display, resolution/Hz and physical-monitor restoration. |
| **Get back safely** | Backups, conflict-aware restore, display recovery shortcut and a redacted diagnostic export. |

## Your games. Front and center.

Real views from the maintainer’s connected libraries. Playnite is the fullscreen interface you stream to your TV.

### Across your stores

Browse an entire connected library, including games ready to install.

<a href="docs/screenshots/en/catalog.png"><img src="docs/screenshots/en/catalog.png" alt="Across your stores" width="100%"></a>

### Your progress comes with you

Compatible emulator history appears directly in the game details.

<a href="docs/screenshots/en/game-details.png"><img src="docs/screenshots/en/game-details.png" alt="Your progress comes with you" width="100%"></a>

<details>
<summary><b>Retro meets the rest · A menu made for the couch</b></summary>

Local emulator games sit alongside your store libraries.

![Retro meets the rest](docs/screenshots/en/emulators.png)

Keep library navigation and settings within reach.

![A menu made for the couch](docs/screenshots/en/library-menu.png)

</details>

## From download to your sofa.

1. **DOWNLOAD & EXTRACT** — Get the Windows x64 ZIP and extract the whole archive. Open <code>Installer.exe</code>.
2. **CONNECT & CONFIGURE** — Use the seven guided pages to select stores, emulators and display settings. Sign in to your own accounts; pair Moonlight with Sunshine.
3. **PICK YOUR SCREEN** — Choose the library or desktop in Moonlight. Come back to the settings app whenever you want to change things.

[Setup guide](docs/guides/en.md) &nbsp; · &nbsp; Windows 10/11 x64 &nbsp; · &nbsp; TV / NVIDIA Shield / Moonlight

### A setup that speaks your language.

English · Türkçe · Français · Español — the installer, worker messages and offline help follow your selection.

<a href="docs/screenshots/en/page-4.png"><img src="docs/screenshots/en/page-4.png" alt="Choose your display" width="100%"></a>

<details>
<summary><b>Explore the setup screens</b></summary>

| Connect your libraries | Pair your TV / Shield |
| :---: | :---: |
| ![Connect your libraries](docs/screenshots/en/page-2.png) | ![Pair your TV / Shield](docs/screenshots/en/page-5.png) |

![Install and maintain](docs/screenshots/en/page-6.png)

</details>

<details>
<summary><b>Before you press play</b></summary>

Windows 10/11 x64, .NET Framework 4.8, PowerShell 5.1, current GPU drivers and a Sunshine-compatible encoder. Internet downloads the selected components.

- Shield, Android TV/Google TV and other Moonlight clients are supported. ADB is optional.
- On Shield, start at 4K60. Higher refresh rates depend on the client’s actual output, decoder, cable, host and network.
- Account login, two-factor authentication and the first PIN pairing are completed on your own devices.
- Some store dialogs and first-run agreements need controller mouse mode or the provider’s UI.
- Historical time needs a supported log and matching game ID. Games, ROMs, BIOS, firmware, keys, saves and patches are not included.

</details>

<details>
<summary><b>Tested, with the scope visible</b></summary>

20 core + 55 backend + 1,950 localization assertions, wizard checks and native Playnite smoke tests. Physical Shield and every hardware combination have not been tested. [Read the validation scope](docs/TESTING.md).

</details>

## Great projects. Shared credit.

Playnite provides the library. Sunshine and Moonlight deliver the stream. SofaRelay adds the guided installation, shared settings, history import and recovery around them.

<p align="center">
  <a href="https://github.com/JosefNemec/Playnite"><b>Playnite</b></a> &nbsp; + &nbsp;
  <a href="https://github.com/SunshineStream/Sunshine"><b>Sunshine</b></a> &nbsp; + &nbsp;
  <a href="https://github.com/moonlight-stream/moonlight-android"><b>Moonlight</b></a>
</p>

VirtualDrivers · Legendary · hawkeye116477 · Libretro · Nefarius · Igor Pavlov · [Meet the projects behind it](docs/CREDITS.md)

## Make the next setup easier.

<!-- SUPPORT-LINK:START -->
<a href="https://buymeacoffee.com/oziooztrk"><img src="docs/media/support/support-en.svg" alt="Support Ozi on Buy Me a Coffee" width="100%"></a>

If this project saves you setup time, you can [buy me a coffee](https://buymeacoffee.com/oziooztrk). Contributions, translations and support for the upstream projects are welcome too. Donations are optional; the software remains free and open source.
<!-- SUPPORT-LINK:END -->

[Contribute](CONTRIBUTING.md) &nbsp; · &nbsp; [Build from source](docs/DEVELOPMENT.md) &nbsp; · &nbsp; [Report an issue](https://github.com/ozi-dev/sofarelay/issues/new/choose) &nbsp; · &nbsp; [Support](docs/SUPPORT.md)

---

<sub>Original integration code: MIT. Third-party software retains its own licenses. Game names and covers shown in documentation belong to their respective owners. <a href="THIRD-PARTY.md">Licenses &amp; notices</a>.</sub>

<p align="center"><sub>An independent community project by <a href="https://github.com/ozi-dev"><b>ozi-dev</b></a>.</sub></p>

## Why SofaRelay?

Playnite supplies the library, Sunshine the host and Moonlight the client. SofaRelay connects their setup: store/emulator integration, compatible playtime history, couch install helpers, Desktop/library tiles, display modes, monitor restoration and a guided four-language settings app. You can still use each upstream project independently.

Fritchii/Lichii are user-selected emulator builds supported through compatible launch/history formats; they are not bundled or endorsed.

## Verification, recovery and removal

Before running the unsigned installer, verify the release checksum and build provenance. Help includes ownership-aware removal, optional sign-in display recovery and LAN-only controls. Sunshine asks you to create your own password; local streaming needs no router port forwarding.

[SHA-256 / provenance](docs/VERIFYING.md) · [Troubleshooting](docs/TROUBLESHOOTING.md) · [Uninstall](docs/UNINSTALL.md) · [Validation / upstream versions](docs/TESTING.md) · [2.3 audit](docs/AUDIT-2.3.md)

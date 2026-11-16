# Built on the work of others

SofaRelay is a setup and integration companion. It does not implement the underlying game-library interface, video encoder, streaming protocol or emulator. Those projects and their communities made this possible.

| Project / people | Contribution to this setup | License / source |
| --- | --- | --- |
| **Playnite — Josef Nemec and contributors** | Game library, fullscreen interface, controller navigation, plugin API and metadata framework | [MIT · source](https://github.com/JosefNemec/Playnite) |
| **Playnite library integration maintainers** | Steam, Epic, Ubisoft, Xbox and metadata connections | [MIT · source](https://github.com/JosefNemec/PlayniteExtensions) |
| **Jeshibu and contributors** | EA app integration used by the selected package | [MIT · source](https://github.com/Jeshibu/PlayniteExtensions) |
| **Sunshine maintainers, including the LizardByte / SunshineStream community** | Host streaming, encoding, input transport and automatic display management | [GPL-3.0 · source](https://github.com/SunshineStream/Sunshine) |
| **Moonlight — cgutman and contributors** | Streaming clients, including Android TV / Shield support | [GPL-3.0 · source](https://github.com/moonlight-stream/moonlight-android) |
| **VirtualDrivers / Virtual Display Driver contributors** | Optional virtual-display driver | [MIT · source](https://github.com/VirtualDrivers/Virtual-Display-Driver) |
| **Legendary developers** | Epic-compatible authentication, library and download tooling | [GPL-3.0 · source](https://github.com/legendary-gl/legendary) |
| **hawkeye116477 and contributors** | Legendary Playnite integration and Unified Download Manager | [Legendary plugin — MIT](https://github.com/hawkeye116477/playnite-legendary-plugin), [download manager — MIT](https://github.com/hawkeye116477/playnite-unifiedDownloadManager-plugin) |
| **Libretro and core developers** | Optional RetroArch frontend and emulation cores | [RetroArch — GPL-3.0](https://github.com/libretro/RetroArch); each core has its own license |
| **Nefarius and contributors** | Optional ViGEmBus controller emulation | [BSD-3-Clause · source](https://github.com/nefarius/ViGEmBus) |
| **Igor Pavlov and 7-Zip contributors** | Unmodified 7za archive extractor used during setup | [7-Zip](https://www.7-zip.org/), bundled license and complete corresponding source under `assets/tools/7zip` |
| **Google / Android Platform Tools** | Optional ADB device inspection and APK installation | [Official tools and SDK terms](https://developer.android.com/tools/releases/platform-tools) |
| **hoverbike1 and TOTK mod contributors** | Upstream reference for optional already-installed local FPS profiles | [Upstream mod collection](https://github.com/hoverbike1/TOTK-Mods-collection); no game patch is redistributed |
| **Fritchii/Lichii and other emulator contributors** | Emulation itself and compatible local history records | Supply your own verified emulator; no emulator fork, games, keys or firmware are bundled |

Please visit, star, contribute to and support the upstream projects as well as this integration. SofaRelay does not replace their support channels for problems inside their own software.

The stores and NVIDIA Shield are trademarks of their respective owners. Their names describe compatibility, not endorsement. Wizard screenshots show this project’s actual localized setup UI with example paths. Fullscreen library screenshots and GIFs show Playnite, including its community translations, using the maintainer’s connected libraries with permission. Game titles, cover art and store logos visible within those screenshots belong to their respective rights holders; they are shown to document the integration. The artwork in the hero diagram is original.

The original integration code and documentation are MIT licensed. Dependencies remain under their own licenses and are downloaded from pinned upstream URLs. [Full distribution notices](../THIRD-PARTY.md).

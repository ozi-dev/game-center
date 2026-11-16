# Third-party software

Oyun Merkezi is an independent integration tool. It is not affiliated with Valve, Epic, EA, Ubisoft, Microsoft, NVIDIA, Nintendo or the listed open-source projects.

The MIT license applies to the original application, integration code and documentation. External programs remain under their own licenses.

The only external executable bundled with this release is unmodified **7-Zip 26.06 Extra x64 7za.exe**, copyright Igor Pavlov, LGPL and other terms described in `assets/tools/7zip/License-26.06.txt`. Corresponding complete source is included in `assets/tools/7zip/7z2606-src.7z`. Source/build instructions and full license notices are inside that archive. Official releases: https://github.com/ip7z/7zip/releases/tag/26.06 . The extractor is run as a separate process and is replaceable; no 7-Zip code is linked into this application.

Other components are downloaded on demand from pinned official URLs with SHA-256 validation. They are not copied from another user's installation:

| Component | Primary source / license |
| --- | --- |
| Playnite and SDK | https://github.com/JosefNemec/Playnite — MIT |
| Built-in Playnite integrations | https://github.com/JosefNemec/PlayniteExtensions — MIT; package notices apply |
| EA Playnite integration | https://github.com/Jeshibu/PlayniteExtensions — package license applies |
| Legendary | https://github.com/legendary-gl/legendary — GPL-3.0 |
| Legendary Playnite integration | https://github.com/hawkeye116477/playnite-legendary-plugin — package license applies |
| Unified Download Manager | https://github.com/hawkeye116477/playnite-unifiedDownloadManager-plugin — package license applies |
| Sunshine | https://github.com/SunshineStream/Sunshine — GPL-3.0 |
| Virtual Display Driver | https://github.com/VirtualDrivers/Virtual-Display-Driver — upstream package license applies |
| ViGEmBus | https://github.com/nefarius/ViGEmBus — BSD-3-Clause |
| Google Platform Tools | https://developer.android.com/tools/releases/platform-tools — Android SDK License Agreement |
| Moonlight Android | https://github.com/moonlight-stream/moonlight-android — GPL-3.0 |
| RetroArch (optional, WinGet) | https://github.com/libretro/RetroArch — GPL-3.0; cores have separate licenses |

Store clients, Microsoft runtime installers and GPU drivers are distributed by their vendors under vendor terms. Selecting an automatic installation accepts the package/source agreements presented by WinGet; account authentication remains in the provider's UI. The Google SDK terms apply to the optional ADB download; use the Play Store route if you do not wish to use Platform Tools. No ROMs, firmware, BIOS, cryptographic keys, saved games, account credentials, pairing keys are included. Documentation screenshots and GIFs contain game covers and titles from the maintainer’s real Playnite library; those remain the property of their respective rights holders. No standalone game artwork assets are distributed. The two generic launcher posters are original project assets. The optional FPS buttons only edit an already installed compatible local profile; no game patches are distributed.

# Public beta and release readiness

SofaRelay is a **public beta**. Automated builds, fixture tests and artifact provenance are available; a fresh-machine hardware validation matrix is not yet complete. Existing releases were initially labelled stable too early. They are now classified as previews without altering their tags, dates or binary assets.

Use the newest beta on the [releases page](https://github.com/ozi-dev/sofarelay/releases). Versions **2.3.0 and earlier have known display-recovery limitations**. Version 2.3.1 fixes the reproduced identity/client-state bugs. Starting with **2.3.2**, new installations keep the physical monitor enabled by default. Existing saved choices remain unchanged; an upgrade does not silently disable a user's explicit monitor-off preference.

## What failed and what changed

The old native restore replayed adapter LUIDs and source/target IDs captured before reboot. Those Windows session identities can change even though the physical monitor is the same. The reproduced old snapshot failed validation with error 87; Sunshine also logged topology errors, including 1610. Recovery now matches the saved monitor's device path to currently enumerated routes, rebinds the IDs in both paths and modes, and restores the saved dimensions, refresh rate and primary position. Missing monitors are rejected instead of being substituted with another display.

The watchdog also used Sunshine's `/serverinfo` BUSY state as a client-presence signal. BUSY can mean an application is retained for resume after the client has disconnected. Recovery now checks current-process connection/session logs, preserves pending or remaining clients, and postpones recovery if that history cannot be established.

These defects affected code shipped in earlier public packages; they were not solely a local settings issue. The installed local runtime had also remained on older code while the GitHub package advanced, leaving that machine without the newer fallback task. An existing installation must actually be updated and its recovery task configured; downloading a ZIP alone does not update a running installation.

## Evidence available

- Windows 2022/2025 CI: core, localization, backend, privacy/security, display identity fixtures, runtime tamper/broker-boundary checks and wizard self-tests. See [test scope](TESTING.md) and the linked workflow runs.
- A real pre-reboot snapshot was rejected by raw replay, validated after rebinding and successfully restored a 3440×1440 / 180 Hz primary monitor. The owner confirmed visible output.
- An actual client disconnect while an application remained BUSY was observed. The limited-user fallback reported Windows code 0 and restored the expected physical layout. Its interactive sign-in trigger was registered.
- A client-specific HEVC stutter improved after H.264 selection on one Android TV. That observation is not a universal codec recommendation; Shield and other TVs need their own comparison.

## Required before stable promotion

Record dated, reproducible results for these cases on clean Windows installations and representative receiving hardware. Do not check a box based only on mocks, an existing configured PC or successful compilation.

- [ ] Fresh installation with Playnite/Sunshine/driver prerequisites absent; verify elevation, component detection and actionable failure messages.
- [ ] Standard account using alternate administrator credentials; verify protected code/state and normal-user ownership boundaries.
- [ ] Real reboot and sign-in with a physical display previously disabled; verify visible output, saved mode/primary layout and task startup.
- [ ] Client disconnect with a retained application, app termination, process crash and reconnect during the recovery grace period.
- [ ] Two simultaneous clients: disconnecting one must preserve the other's stream.
- [ ] Physical cable removal/reconnection, changed port, multiple physical monitors and unsupported modes; recovery must report missing devices without selecting an unrelated output.
- [ ] Install interruption, restore conflicts and uninstall with pre-existing shared components; verify that games, accounts and shared driver files are preserved.
- [ ] Actual Android TV and Shield playback, controller/input, SDR/HDR and supported refresh modes; test under game load.

Tag-triggered workflows publish pre-releases. A maintainer may promote a release after recording the applicable hardware results, reviewed limitations and recovery/removal instructions. CI success and SHA-256/provenance verification are necessary checks; they do not prove hardware compatibility or replace an independent review. No stable-readiness claim is made until that work is recorded.

## Four-language summary

**Türkçe:** Ürün genel beta aşamasındadır. 2.3.1 yeniden başlatma sonrası ekran kimliği ve kapalı yayın/meşgul uygulama ayrımını düzeltir. 2.3.2 yeni kurulumlarda fiziksel monitörü açık bırakır; mevcut tercihler korunur. Gerçek temiz kurulum, yeniden başlatma ve kaldırma testleri tamamlanmadan stabil uyumluluk garantisi verilmez.

**Français :** Le produit est en bêta publique. La version 2.3.1 corrige les identités d'écran après redémarrage et la distinction entre application conservée et client connecté. La version 2.3.2 laisse le moniteur physique activé par défaut pour les nouvelles installations ; les choix existants sont conservés. La validation complète sur machine propre, après redémarrage et à la désinstallation reste à réaliser.

**Español:** El producto está en beta pública. La versión 2.3.1 corrige las identidades de pantalla tras reiniciar y distingue la aplicación retenida del cliente conectado. La versión 2.3.2 mantiene el monitor físico encendido por defecto en instalaciones nuevas; conserva las preferencias existentes. Falta completar la validación en equipos limpios, tras reiniciar y al desinstalar.

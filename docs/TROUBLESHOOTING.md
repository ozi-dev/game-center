# Troubleshooting

Start at **Help → Diagnose**, then export the redacted diagnostic file. Review it before attaching it to an issue. Do not attach complete runtime folders, provider configuration or raw logs containing account data.

| Symptom | Checks and recovery |
| --- | --- |
| Black screen / physical monitor stays off | End the stream. Use **Start → SofaRelay → Restore Display** or **Ctrl+Alt+F11**. Sunshine's disconnect restoration is enabled when selected. The optional watchdog waits for three confirmed idle checks; unknown stream state postpones recovery. After a restart it runs at the next user sign-in, not before login. If the driver/OS failed, use Windows display settings or recovery mode. |
| No audio | Check Windows' selected playback device, Sunshine audio configuration and Moonlight audio settings. Reconnect after selecting a valid output; do not uninstall audio drivers as a first step. |
| Controller not detected | Enable controller input in SofaRelay, verify the supported gamepad driver in diagnosis, reconnect Moonlight and configure the emulator's controller mapping. ViGEm is an upstream end-of-life compatibility option; another existing driver is preserved. |
| PIN pairing fails | Put PC and client on the same trusted LAN, turn off guest-network isolation, open Sunshine's local web UI and enter Moonlight's current PIN. The owner creates Sunshine's password; SofaRelay supplies no default password. |
| Shield above 60 Hz | Check the exact Shield model, HDMI mode/cable, TV input mode and Moonlight's device-supported frame-rate options. A high-Hz TV does not prove that this client's HDMI output supports that mode. Choose a mode actually advertised by the client; a virtual PC display cannot raise the HDMI limit. |
| HDR wrong / washed out | First establish SDR streaming. Then confirm HDR support and settings on the host GPU, virtual display, Sunshine, Moonlight and TV. HDR must work across the whole chain. |
| PC absent / firewall | Use a Windows **Private** profile only on a trusted LAN. LAN-only rules target Sunshine's exact executable and LocalSubnet, with no router changes. A Public profile is deliberately excluded. Check other security software and custom Sunshine ports. Do not open ports to the internet or enable UPnP for this local setup. Broader third-party/group-policy firewall rules need separate review. |
| Setup refuses active/unknown stream | End the stream first. An unreadable Sunshine state is treated conservatively. Custom server-info ports may require manual configuration; they are not guessed. |
| Package hash / signer check fails | Delete the cached failed download and use the official full release. Retry after confirming the pinned upstream package; report a certificate change. Do not bypass the check. |
| Component directory permission error | The elevated broker accepts administrator-owned component paths only. Review/reinstall the official component; do not elevate the whole GUI or grant Everyone write access. |
| Install opens a store client | Epic's supported direct downloads require Legendary authentication. Steam confirmations can change upstream; unsupported store workflows use the documented controller-mouse fallback. |
| Emulator time / cover missing | Check title IDs, selected ROM/profile path, supported playtime record format and Playnite metadata download. Fritchii/Lichii names refer to user-selected emulator builds; they are not bundled, endorsed or assumed to be a specific console generation. |

See [verification](VERIFYING.md), [removal](UNINSTALL.md) and [test limits](TESTING.md).

Türkçe: Siyah ekranda önce yayından çıkın ve **Restore Display / Ctrl+Alt+F11** kullanın. Eşleşme ve ağ sorunlarında aynı güvenilir yerel ağı ve Private profilini kontrol edin. Shield'ın HDMI sınırı TV'nin yenileme hızından farklı olabilir. Tanı dışa aktarımını paylaşmadan önce inceleyin.

Français : En cas d'écran noir, quittez le streaming puis utilisez **Restore Display / Ctrl+Alt+F11**. Vérifiez le réseau local de confiance et le profil Private. La limite HDMI du Shield peut différer de celle du téléviseur. Relisez le diagnostic avant de le partager.

Español: Si la pantalla queda negra, termina la transmisión y usa **Restore Display / Ctrl+Alt+F11**. Comprueba la LAN de confianza y el perfil Private. El límite HDMI de Shield puede ser distinto al del televisor. Revisa el diagnóstico antes de compartirlo.

# Validation for 2.3.1

The implementation is checked against isolated project fixtures on Windows 11 x64, PowerShell 5.1, .NET Framework 4.8 and Playnite 10.64. The current CI matrix runs **windows-2022 and windows-2025**. Test output and release provenance provide the actual run status; a configured workflow alone is not evidence of a passing run.

| Check | Scope |
| --- | --- |
| Core assertions | 29 checks including playtime imports/overlap/reset, title matching, migration, mode validation and crash/sign-in/unknown/active-stream recovery policy. |
| Localization assertions | 2,062 checks over 255 keys in EN/TR/FR/ES: exact key parity, nonempty translations, placeholder equality, normalization, validation and persistence. |
| Backend fixtures (62 assertions) | Atomic writes/backups, ZIP/path traversal, quoting, provider IDs/auth preservation, real configuration apply/reapply/restore/conflict preflight and upgrades. System/driver/service boundaries are mocked. |
| Pester security/privacy (17 tests) | Bad-download cleanup, whole-ZIP preflight, forged protected targets/backups, valid-but-wrong signers, exact-byte configuration rollback, shared-component preservation, invalid driver ownership, firewall preflight and active/paused/multiple-client log interpretation. |
| Display identity assertions | 11 pure checks: adapter LUID/source/target rebinding after reboot, saved mode/layout preservation, immutable original snapshots, missing monitor rejection and invalid references. No display API is invoked by this fixture executable. |
| Broker boundary checks | Local path confinement, existing result rejection, mismatched owner/system root rejection, junction rejection, runtime directory lease prevents rename while permitting child result writes. No UAC/elevation occurs. |
| Actual Diagnostics action | Runs the real worker against read-only system diagnosis; examines the exported schema for current username/hostname, addresses, paths and account fields. Injected token/email/name fixtures are separate Pester tests. |
| Runtime tamper checks | An unchanged runtime succeeds; altered Worker.ps1, changed package manifest and an injected operation are rejected before setup. |
| Static analysis | All tracked PowerShell is parsed; selected PSScriptAnalyzer security rules reject IEX, empty catches, plaintext credential patterns and related issues. No machine-wide execution-policy mutation. |
| UI/package | Seven-page wizard self-test; broker embedded-payload self-test; explicit public allowlist, per-file/ZIP SHA-256; local documentation references and four-language navigation. |

Reproduce in separate PowerShell processes (loaded DLLs remain locked):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build.ps1 -PlayniteSdkPath "D:\Playnite\Playnite.SDK.dll"
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\BackendTests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\maintainer\Run-SecurityTests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\maintainer\Test-Scripts.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\BrokerBoundaryTests.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\DiagnosticsSmoke.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\RuntimeIntegrityTests.ps1
.\build\SofaRelay.exe --selftest
python scripts/maintainer/CheckPublic.py --tracked
python scripts/maintainer/CheckLinks.py --offline
```

## Limits requiring a clean VM / receiving hardware

During the 2.3.1 incident investigation, an actual pre-reboot physical-monitor snapshot failed raw validation with Windows error 87. Rebinding the same snapshot to current device identities validated successfully; applying it restored the saved 3440×1440 / 180 Hz primary display and the owner confirmed visible output. The existing Sunshine disconnect path then cleared its stale persisted state. A limited-user recovery task with an interactive sign-in trigger was installed on that host. An actual client disconnect while the application remained BUSY was then observed: client activity changed to idle, the task reported Windows code 0 and the physical 3440×1440 / 180 Hz primary layout was confirmed by enumeration. These observations do not substitute for a forced reboot/power-loss test, which was not performed during an active game.

A fresh end-to-end elevated broker install/uninstall, alternate-admin UAC, power interruption during machine changes, real reboot/sign-in restoration, driver-store cleanup and forced process-crash hardware restoration have **not** been validated by these fixture tests. Real Sunshine/ViGEm/VDD installation, physical Shield playback/HDMI high refresh/HDR, ADB authorization and store account interaction require first-use validation on the receiving computer. Tests do not silently change the maintainer's live streaming settings. Recovery-policy simulations are not hardware recovery tests. The watchdog cannot repair firmware/OS failures or guarantee a pre-login display.

Driver/MSI installs may remain after later setup failure; uninstall removes only proven owned components and leaves shared driver-store/files/state for manual review. There is no claim of a universally automatic clean uninstall. Source changes are not an independent human security audit. Signing remains pending owner/provider approval.

## Existing feature evidence

Earlier validation loaded the native extension in fresh portable Playnite, imported a synthetic scanner/title and 1,234-second record without launching a game, and verified repeated setup preserved profile IDs and duration. Migration preserves library state, the legacy extension IDs and owned shortcuts. Playnite version detection reads its managed assembly rather than the native bootstrapper's 1.0 file metadata.

Documentation images show the maintainer's real connected libraries in each native Playnite language; databases and account data are excluded. Wizard screenshots show example paths. Some screenshots predate the 2.3 security controls; guides describe the current options.

## Reviewed upstream pins

This table means pinned bytes/signatures and integration code were reviewed, **not** that every hardware path was exercised:

| Component | Pinned version | Evidence / boundary |
| --- | --- | --- |
| Playnite | 10.64 | SDK compilation, extension/import and configuration fixtures. |
| Sunshine | 2026.914.233613 | Verified MSI hash/signer; configuration fixtures, no new live service install in this audit. |
| Moonlight Android | 12.1 | Verified package pin; Shield/TV playback needs device validation. |
| Virtual Display Driver | 25.7.23 | Verified ZIP/catalog signer; native/configuration code tests, no new device installation. |
| ViGEmBus | 1.22.0 | Verified installer signer; optional compatibility driver, upstream end-of-life. |
| Legendary CLI / Playnite extension | 0.21.1 / 1.17.0 | Fixed downloads; account login/download behavior depends on upstream. |

See [audit report](AUDIT-2.3.md), [security model](../SECURITY.md), [verification](VERIFYING.md) and [troubleshooting](TROUBLESHOOTING.md).

Local unsigned reproducibility check: independent output directories produced matching hashes for seven binaries and byte-identical ZIPs; all 382 listed payload checksums were verified. The final release is rebuilt in CI from its tag rather than reusing that local test ZIP.

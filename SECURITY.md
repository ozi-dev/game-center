# Reporting security issues

**Release channel: public beta.** See [release readiness](docs/RELEASE-STATUS.md). CI, checksums and provenance do not establish full hardware compatibility. New installs keep physical-monitor shutdown off starting with 2.3.2.

Use this repository's **Security → Report a vulnerability** option if available. Include affected version, impact and a minimal reproduction. Do not publish live tokens, passwords, account exports, keys or unredacted personal logs. If private reporting is unavailable, open a minimal issue asking for a private contact channel without publishing exploit details.

## Trust model (2.3)

The downloaded GUI, its Core DLL and the first broker bootstrap executable form the initial trust boundary. They are currently unsigned: verify the official ZIP checksum and GitHub provenance before running them. Runtime hashes are compiled into the GUI, and the broker's code/manifests are embedded in its executable. A mutable hash list beside mutable files is not treated as an authenticity guarantee.

The GUI verifies/locks runtime files before starting a worker. It requests UAC only for a standalone, hash-bound broker, holding the broker EXE and startup configuration against replacement during consent. The broker installs its embedded code under administrator/SYSTEM-owned **%ProgramFiles%\SofaRelay\Broker\<version>**. Elevated PowerShell runs only this protected copy, uses compiled native helpers, a fixed operation allowlist, restricted module/PATH locations and process-only ExecutionPolicy Bypass. It never compiles user-writable C# or elevates a user-writable Worker.ps1.

Settings are untrusted requests, not elevated code. The broker binds the local runtime directory to the request file's Windows owner SID, rejects reparse points, restricts result filenames and holds runtime/data directory leases. Machine identity, ownership and elevated backup journals live under administrator/SYSTEM-owned **%ProgramData%\SofaRelay**; the original requesting account can read its state but cannot write it. Privileged restore accepts only the exact discovered Sunshine configuration files and standard VDD settings file, with backups confined to the protected state directory. It never elevates a legacy user-written journal. User-level configuration restore, settings writes and watchdog state run with the caller's normal token.

Pre-existing unprotected broker/state/component directories are rejected rather than silently taken over. VDD privileged configuration is limited to **C:\VirtualDisplayDriver**; other driver locations require manual configuration. Standard-account UAC with alternate administrator credentials is represented by the requesting SID; a clean-VM end-to-end validation of that path remains required.

This reduces the reviewed mutable-script/journal attack paths. It does **not** establish trust if someone replaces the whole unsigned application before first use, modifies an already-loaded GUI/Core DLL, controls the user's processes/environment, has administrator access, or compromises the OS/toolchain/upstream. No defense against an already fully compromised account is claimed. This is a source-level remediation and automated-test report, not an independent human security audit.

## Downloads, privileges and network

Project-managed downloads have fixed versions and SHA-256; reviewed signed components also require valid Authenticode plus a certificate thumbprint allowlist. Failure stops the step and deletes the partial download. Optional WinGet/vendor clients auto-update independently. No remote Invoke-Expression or machine-wide execution-policy change is used. Run the GUI normally; the broker alone requests elevation for system operations. Drivers/MSI installers are external transactions: a failed later configuration step does not guarantee that an already-installed prerequisite is removed; ownership remains recorded for reviewed removal.

LAN-only mode disables Sunshine UPnP, restricts its web UI to the PC and narrows exact-executable inbound firewall rules to **Private / LocalSubnet**. No router port forwarding is required or configured. It does not disable Windows Firewall or audit unrelated/group-policy rules. Sunshine's owner creates the password and performs PIN pairing; SofaRelay creates no default credential.

## Recovery, removal and privacy

Configuration writes and task/firewall changes have rollback paths for caught failures. Power loss, driver crashes and concurrent administrative edits can still require manual recovery. The optional watchdog runs unelevated, waits for confirmed idle state and runs after reboot at the next interactive sign-in. Unknown state postpones recovery. [Recovery and troubleshooting](docs/TROUBLESHOOTING.md) describe these limits.

Removal uses protected ownership, preserves shared components and deliberately retains driver-store/shared files and protected backup state for review. See [removal](docs/UNINSTALL.md).

Diagnostic exports use a strict schema allowlist plus text redaction; raw settings, accounts, network addresses, local logs and paths are excluded. Tests inject credentials, emails and names and exercise the real Diagnostics action. Other local logs/error reports may contain paths or personal text. Review files before sharing; no redactor can guarantee detection of every arbitrary secret. See [verification](docs/VERIFYING.md) and [test evidence](docs/TESTING.md).

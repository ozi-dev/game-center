# Reporting security issues

For a suspected vulnerability, use this repository's **Security → Report a vulnerability** option if available. Describe the affected version, impact and minimal reproduction. Do not include live tokens, passwords, account exports, private keys or unredacted personal logs.

If private reporting is unavailable, open a minimal issue asking for a private contact channel without publishing exploit details or secrets.

The installer is unsigned. Download the release from `ozi-dev/game-center`, verify the SHA-256 values, or build from source. Third-party packages are pinned and hash-checked; signed system installers/drivers also receive signature checks. No step requires disabling Windows security features.

Account login, administrator elevation and device authorization remain with the owner. Diagnostics export excludes account identifiers, IP addresses and ROM paths; other local logs can still contain personal information.

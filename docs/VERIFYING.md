# Verify a download

Download the complete Windows x64 ZIP and `SHA256SUMS.txt` from the same [official release](https://github.com/ozi-dev/sofarelay/releases). Before extracting or running it, compare the full 64-character digest:

```powershell
Get-FileHash .\SofaRelay-2.3.0-Windows-x64.zip -Algorithm SHA256
Get-Content .\SHA256SUMS.txt
```

Stop if they differ. A checksum detects changed bytes; a checksum downloaded beside a file does not independently prove who built it.

For releases starting with 2.3.0, verify GitHub's build-provenance attestation with a current [GitHub CLI](https://cli.github.com/):

```powershell
gh attestation verify .\SofaRelay-2.3.0-Windows-x64.zip --repo ozi-dev/sofarelay --signer-workflow ozi-dev/sofarelay/.github/workflows/release.yml
```

The release also includes `provenance.intoto.jsonl`; the CLI can verify that bundle with `--bundle .\provenance.intoto.jsonl`. Check the expected repository, tag and workflow identity in the output. See [GitHub CLI's verification documentation](https://cli.github.com/manual/gh_attestation_verify). Provenance associates bytes with a workflow and source revision; it is not a security audit or an Authenticode signature. Older releases do not have this attestation.

## SmartScreen and signing

SofaRelay's own EXE/DLL files are currently **unsigned**. Windows may show an unknown-publisher or SmartScreen warning. Do not disable Defender, SmartScreen, signature enforcement or UAC. Verify the source and checksums/provenance first; if verification fails or you do not trust the download, stop. A warning should not be dismissed solely because this guide mentions it.

SignPath Foundation is a possible signing provider, subject to its [eligibility and approval requirements](https://signpath.org/terms). No application approval, signing certificate or signed release is claimed. See [signing preparation](SIGNING.md).

## Dependency trust

Project-managed downloads have fixed versions and SHA-256 values in `manifests/packages.json`. A mismatched/incomplete download is discarded. Playnite's executable, Sunshine/ViGEm installers and the VDD catalog must additionally have a valid Authenticode signature matching a reviewed certificate thumbprint. An expired/rotated certificate needs a maintainer review, not a check bypass.

Optional store clients and RetroArch use WinGet/vendor channels and may auto-update; those live versions are outside this project's fixed-download guarantee. Accounts are connected in the official clients or Playnite extensions. No account credentials are included in releases.

## Rebuild

`VERSION` is the release number source. The compiler and test tools are pinned in `manifests/build-tools.json`. Builds use Roslyn deterministic compilation; ZIP entries have sorted names and fixed timestamps. Repeating a clean build/package with the same commit, SDK, Windows/.NET toolchain and line endings should produce identical unsigned artifacts. Different toolchains and future timestamped Authenticode signatures may change bytes. Build metadata records the source commit; reproducibility is distinct from provenance.

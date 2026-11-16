# Contributing

Thanks for helping. Useful contributions include reproducible bug reports, tested fixes, store/emulator compatibility notes, accessibility improvements and translations.

1. Check existing issues, then describe one concrete problem or improvement.
2. Fork the repository and use a focused branch.
3. Follow the [build guide](docs/DEVELOPMENT.md). For code changes, run checks appropriate to the affected component and describe what you actually tested.
4. Keep documentation and all four README translations consistent when behavior changes. Installer UI localization is a separate future improvement.
5. Open a pull request with the before/after behavior, validation and any limitations.

Preserve existing libraries, playtime, account settings and display state. Do not bypass package hash checks, driver signatures, account authentication or device authorization. Do not add ROMs, firmware, keys, saves, personal logs, credentials or copied user data.

Use synthetic fixtures for automated tests. Do not launch or install a real game just to exercise a code path. Protected system boundaries must be mocked in automated configuration tests.

Credits and upstream licenses matter. If code or assets are incorporated from another project, state the source and license and retain the required notices. Contributions are made under this repository's MIT license unless clearly identified as a third-party component.

For documentation-only changes, run the public-content/link checker; rebuilding the application is generally unnecessary.

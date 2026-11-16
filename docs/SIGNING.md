# Signing preparation

Current releases are unsigned. [SignPath Foundation](https://signpath.org/terms) requires owner onboarding, project eligibility review and approval. No credentials, approved organization, certificate or signing policy exist in this repository. This cannot be completed by inventing workflow secrets.

Before enabling a signing job, the repository owner must obtain approval and configure a narrowly scoped signing policy. Review the published source license, upstream credits, release provenance and responsible maintainers.

The current integrity graph dictates signing order: build/sign Core and Native DLLs before embedding them in the broker payload; build/sign the broker before embedding its expected hash in the GUI; build/sign the GUI last, then copy it to Installer.exe. Package hashes and provenance must be calculated **after** signing. Independently signing the final broker after the GUI was built would intentionally fail runtime verification. Implement and test this ordering before claiming signed support.

Timestamped signed artifacts may not be byte-identical across builds. Keep unsigned reproducibility checks separate. Never store a private signing key in the repository or run an unreviewed remote signing script.

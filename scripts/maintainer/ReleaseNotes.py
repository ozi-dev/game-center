"""Extract the exact SemVer section; never infer release dates or rewrite history."""
from pathlib import Path
import re,sys
root=Path(__file__).resolve().parents[2]
version=(root/'VERSION').read_text().strip()
if len(sys.argv)>1 and sys.argv[1]!='v'+version:raise SystemExit('Tag must match VERSION')
text=(root/'CHANGELOG.md').read_text('utf-8-sig')
match=re.search(r'^## '+re.escape(version)+r'(?:[^\n]*)\n(.*?)(?=^## |\Z)',text,re.M|re.S)
if not match:raise SystemExit('CHANGELOG.md has no section for '+version)
print('# SofaRelay '+version+'\n\n'+match.group(1).strip())
print('\n**Public beta.** Fresh Windows installation, real reboot/sign-in display recovery and full removal still require the receiving-hardware checks in [Release status](https://github.com/ozi-dev/sofarelay/blob/main/docs/RELEASE-STATUS.md). Physical-monitor shutdown is off by default for new installations starting with 2.3.2; existing explicit choices are preserved. Automated tests and provenance do not establish universal hardware compatibility.')
print('\nDownload the complete Windows x64 ZIP, verify its checksum and provenance, then open **Installer.exe**. [Verification instructions](https://github.com/ozi-dev/sofarelay/blob/main/docs/VERIFYING.md).')

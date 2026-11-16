"""Check the staged/tracked public tree without opening ignored private data."""
import argparse
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote

root = Path(__file__).resolve().parents[2]
parser = argparse.ArgumentParser()
parser.add_argument('--tracked', action='store_true', help='Check HEAD/index tracked paths (default also uses index).')
args = parser.parse_args()
result = subprocess.run(['git', 'ls-files', '-z'], cwd=root, check=True, capture_output=True)
names = [x.decode('utf8') for x in result.stdout.split(b'\0') if x]
if not names:
    sys.exit('No staged/tracked public files. Stage the source allowlist first.')
tracked = set(names)
failures = []
text_suffixes = {'.md', '.html', '.svg', '.cs', '.ps1', '.psm1', '.py', '.json', '.yaml', '.yml', '.txt'}
for name in names:
    path = root / name
    if re.search(r'(^|/)(data|downloads|reports|dist|build|product-build|release-build|library|ExtensionsData|third-party)(/|$)', name, re.I):
        failures.append(f'Private/generated path: {name}')
    if re.search(r'\.(nup|nsp|xci|rom|sav|db|pfx|pem)$', name, re.I):
        failures.append(f'Private payload type: {name}')
    if path.suffix.lower() not in text_suffixes:
        continue
    text = path.read_text(encoding='utf-8-sig')
    normalized = text.replace('\\\\', '\\')
    if re.search(r'[A-Za-z]:[\\/]+Users[\\/]+[^\\/\s"<>]+', normalized, re.I):
        failures.append(f'Personal absolute user path: {name}')
    if re.search(r'\b(?:ghp_|gho_|github_pat_)[A-Za-z0-9_]{20,}', text):
        failures.append(f'Possible GitHub credential: {name}')
    if path.suffix.lower() in {'.md', '.html'}:
        targets = re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', text)
        targets += re.findall(r'(?:src|href)="([^"]+)"', text)
        for target in targets:
            target = target.strip().split(' "', 1)[0]
            if re.match(r'^(https?://|mailto:|#)', target):
                continue
            target = unquote(target.split('#', 1)[0])
            if not target:
                continue
            resolved = (path.parent / target).resolve()
            try:
                relative = resolved.relative_to(root).as_posix()
            except ValueError:
                failures.append(f'Link leaves project: {name}: {target}')
                continue
            if not resolved.exists():
                failures.append(f'Missing local target: {name}: {target}')
            elif resolved.is_file() and relative not in tracked:
                failures.append(f'Target not published: {name}: {target}')
for name in ['README.md', 'docs/readme/tr.md', 'docs/readme/fr.md', 'docs/readme/es.md']:
    text = (root / name).read_text('utf8')
    if not all(language in text for language in ['English', 'Türkçe', 'Français', 'Español']):
        failures.append(f'Missing language navigation: {name}')
if failures:
    print('\n'.join(failures))
    sys.exit(1)
print(f'PASS public tree: {len(names)} files; private payloads, credential patterns, documentation links and four-language navigation checked.')

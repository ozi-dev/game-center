"""Verify pinned official downloads. Changes to versions/hashes require review."""
import argparse,hashlib,json,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser();parser.add_argument('--id',action='append');args=parser.parse_args()
manifest=json.loads((root/'manifests/packages.json').read_text('utf-8-sig'))
cache=root/'downloads';cache.mkdir(exist_ok=True)
for item in manifest['Packages']:
 if args.id and item['Id'] not in args.id:continue
 target=cache/item['FileName']
 if target.parent!=cache:raise ValueError('Invalid filename')
 if not target.exists():urllib.request.urlretrieve(item['Url'],target)
 with target.open('rb') as stream:digest=hashlib.file_digest(stream,'sha256').hexdigest()
 if digest.lower()!=item['Sha256'].lower():raise ValueError('Hash mismatch: '+item['Id'])
 print('Verified',item['Id'],item['Version'])

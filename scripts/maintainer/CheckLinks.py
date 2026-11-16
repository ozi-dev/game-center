"""Validate tracked documentation links; weekly mode also checks public HTTP pages."""
import argparse,concurrent.futures,re,subprocess,sys
from pathlib import Path
from urllib.parse import urlsplit,unquote
from urllib.request import Request,urlopen
from urllib.error import HTTPError
root=Path(__file__).resolve().parents[2]
parser=argparse.ArgumentParser()
parser.add_argument('--offline',action='store_true')
args=parser.parse_args()
names=subprocess.check_output(['git','ls-files'],cwd=root,text=True).splitlines()
failures=[];urls=set();count=0
for name in names:
    path=root/name
    if path.suffix not in {'.md','.html'}:continue
    text=path.read_text('utf-8-sig')
    targets=re.findall(r'!?\[[^\]]*\]\(([^)]+)\)',text)+re.findall(r'(?:href|src)="([^"]+)"',text)
    for target in targets:
        target=target.split(' "',1)[0].strip('<> ').replace('&amp;','&')
        parts=urlsplit(target)
        if parts.scheme in {'http','https'}:
            # Local setup endpoints and loopback URLs are intentionally offline.
            if parts.hostname not in {'localhost','127.0.0.1','0.0.0.0'}:urls.add(target.split('#')[0])
            continue
        if parts.scheme:continue
        dest=(path.parent/unquote(parts.path)).resolve() if parts.path else path
        count+=1
        if not dest.exists():failures.append(f'{name}: missing {target}')
        elif parts.fragment and dest.suffix=='.md':
            body=dest.read_text('utf-8-sig')
            headings=re.findall(r'^#{1,6}\s+(.+)',body,re.M)
            anchors={re.sub(r'[^\w\- ]','',h.lower()).replace(' ','-') for h in headings}
            anchors.update(re.findall(r'(?:id|name)="([^"]+)"',body))
            if unquote(parts.fragment) not in anchors:failures.append(f'{name}: missing anchor {target}')
def check(url):
    # Release binaries have hash/signature tests, not an expensive documentation GET.
    if '/releases/download/' in url:return None
    try:
        with urlopen(Request(url,headers={'User-Agent':'SofaRelay-link-check/1.0'},method='GET'),timeout=25) as response:
            response.read(1024)
    except HTTPError as error:
        if error.code in {403,429}:return f'NOTICE {error.code} bot/rate restriction: {url}'
        return f'ERROR HTTP {error.code}: {url}'
    except Exception as error:return f'ERROR {type(error).__name__}: {url}'
    return None
if not args.offline:
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as executor:
        for result in executor.map(check,sorted(urls)):
            if result:
                print(result)
                if result.startswith('ERROR'):failures.append(result)
if failures:
    print('\n'.join(failures));sys.exit(1)
print(f'PASS {count} local documentation references; {len(urls)} unique public URLs'+(' (network deferred to weekly workflow)' if args.offline else ' checked (403/429 reported separately)'))

"""Read-only upstream release report. Never edit pins, hashes or install anything."""
import json,os,urllib.request
from pathlib import Path
root=Path(__file__).resolve().parents[2]
packages={p['Id']:p for p in json.loads((root/'manifests/packages.json').read_text('utf-8-sig'))['Packages']}
repositories={'playnite':'JosefNemec/Playnite','sunshine':'LizardByte/Sunshine','vigem':'nefarius/ViGEmBus','moonlight':'moonlight-stream/moonlight-android','legendary-cli':'derrod/legendary','vdd':'VirtualDrivers/Virtual-Display-Driver'}
lines=['## Upstream release review','', '| Component | Reviewed pin | Latest upstream tag |','| --- | --- | --- |']
failed=False
for component,repo in repositories.items():
    headers={'User-Agent':'SofaRelay-upstream-review'}
    if os.getenv('GH_TOKEN'):headers['Authorization']='Bearer '+os.environ['GH_TOKEN']
    try:
        request=urllib.request.Request('https://api.github.com/repos/'+repo+'/releases/latest',headers=headers)
        with urllib.request.urlopen(request,timeout=30) as response:release=json.load(response)
        latest=f"[{release['tag_name']}]({release['html_url']})"
    except Exception as error:
        latest='LOOKUP FAILED: '+type(error).__name__;failed=True
    lines.append(f"| {component} | {packages[component]['Version']} | {latest} |")
lines+=['','Different tags require a maintainer review of release notes, download checksum, signing certificate and compatibility tests. No automatic pin updates. Playnite extension updates are reviewed against their manifests; optional store clients use vendor/WinGet update channels.']
report='\n'.join(lines)+'\n'
print(report)
if os.getenv('GITHUB_STEP_SUMMARY'):
    with open(os.environ['GITHUB_STEP_SUMMARY'],'a',encoding='utf8') as output:output.write(report)
if failed:raise SystemExit('An upstream lookup failed; inspect the job summary.')

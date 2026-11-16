"""Render bundled offline help. Maintainer-only dependency: pip install Markdown."""
from pathlib import Path
import re
import markdown

ROOT = Path(__file__).resolve().parents[2]
STYLE = """body{margin:0;background:#101827;color:#e7edf6;font:17px/1.65 system-ui,Segoe UI,sans-serif}main{max-width:1050px;margin:auto;padding:40px 24px 90px}a{color:#83d6ff}h1,h2{line-height:1.3;color:white}h2{margin-top:40px}table{border-collapse:collapse;width:100%}td,th{border:1px solid #42506a;padding:10px;text-align:left;vertical-align:top}pre,code{background:#20304a;border-radius:4px;padding:3px 6px}pre{padding:15px;overflow:auto}img{max-width:100%}li{margin:8px 0}@media print{body{background:white;color:#111}h1,h2{color:#111}a{color:#167}}"""

for language in ("en", "tr", "fr", "es"):
    source = ROOT / "docs" / "guides" / (language + ".md")
    body = markdown.markdown(source.read_text("utf-8"), extensions=["tables", "fenced_code", "toc"])
    body = '<span id="gereksinimler"></span>' + body
    emulator_headings = {"en": "Emulator history and artwork", "tr": "Bilmekte fayda var", "fr": "Utilisation quotidienne", "es": "Uso diario"}
    marker = re.compile(r'(<h2[^>]*>' + re.escape(emulator_headings[language]) + r'</h2>)')
    body = marker.sub(r'<span id="emulatorler"></span>\1', body)
    for code in ("en", "tr", "fr", "es"):
        body = body.replace('href="' + code + '.md"', 'href="' + code + '.html"')
    body = re.sub(r'href="(?:\.\./\.\./README|\.\./readme/(?:tr|fr|es))\.md"', 'href="'+language+'.html"', body)
    title = re.search(r"<h1[^>]*>(.*?)</h1>", body).group(1)
    page = '<!doctype html>\n<html lang="'+language+'"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+title+'</title><style>'+STYLE+'</style></head><body><main>'+body+'</main></body></html>\n'
    source.with_suffix(".html").write_text(page, encoding="utf-8")
    print("Rendered", source.with_suffix(".html").relative_to(ROOT))

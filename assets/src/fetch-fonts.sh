#!/bin/sh
# Download the Google Fonts used by figs.html into ./fonts (not committed).
set -eu
cd "$(dirname "$0")" && mkdir -p fonts && cd fonts
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
curl -sS -A "$UA" "https://fonts.googleapis.com/css2?family=Archivo:wdth,wght@62..125,400..900&family=Noto+Sans+SC:wght@400;700;900&family=JetBrains+Mono:wght@500;700&display=block" -o raw.css
python3 - <<'PY'
import re, hashlib
css = open('raw.css').read()
with open('list.txt', 'w') as f:
    for u in sorted(set(re.findall(r'url\((https://[^)]+)\)', css))):
        fn = hashlib.md5(u.encode()).hexdigest()[:12] + '.woff2'
        css = css.replace(u, fn)
        f.write(f'url = "{u}"\noutput = "{fn}"\n')
open('fonts.css', 'w').write(css)
PY
curl -sS --parallel -K list.txt

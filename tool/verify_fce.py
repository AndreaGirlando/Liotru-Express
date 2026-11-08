#!/usr/bin/env python3
"""Capture the official FCE feed and inspect its standard and extension tables."""
import csv
import io
import json
import time
import urllib.request
import zipfile
from pathlib import Path
from datetime import datetime, timezone

OUT = Path('fce-verification')
OUT.mkdir(exist_ok=True)
URL = 'https://www.circumetnea.it/download/general-transit-feed-specification-fce-01-02-2025-28-02-2028/?wpdmdl=17798'
report = {'checked_at': datetime.now(timezone.utc).isoformat(), 'url': URL}
try:
    request = urllib.request.Request(URL + '&refresh=' + str(int(time.time())), headers={'User-Agent': 'CataniaBus-personal-source-check/2.2'})
    with urllib.request.urlopen(request, timeout=30) as response:
        data = response.read(30_000_001)
        if len(data) > 30_000_000:
            raise ValueError('FCE response exceeds 30MB')
        report.update(status=response.status, bytes=len(data), content_type=response.headers.get('Content-Type'))
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        (OUT / 'official-fce.zip').write_bytes(data)
        report['tables'] = {}
        for name in archive.namelist():
            if not name.endswith('.txt'):
                continue
            with archive.open(name) as stream:
                rows = list(csv.DictReader(io.TextIOWrapper(stream, encoding='utf-8-sig')))
            report['tables'][name] = {'rows': len(rows), 'sample': rows[:3]}
        print('FCE HTTP',report['status'],'ZIP',report['bytes'],'tables',len(report['tables']))
except Exception as error:
    report['error'] = str(error)
    print('FCE source check:', str(error))
(OUT / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2))

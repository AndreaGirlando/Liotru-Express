#!/usr/bin/env python3
"""Verifica riproducibile delle fonti pubbliche; non inventa feed alternativi."""
import csv
import io
import json
import re
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from datetime import datetime, timezone
from html import unescape
from pathlib import Path

OUT = Path('source-verification')
OUT.mkdir(exist_ok=True)
report = {'checked_at': datetime.now(timezone.utc).isoformat(), 'sources': []}


def fetch(url, limit=20_000_000):
    request = urllib.request.Request(url, headers={
        'User-Agent': 'CataniaBus-personal-source-check/2.2',
        'X-BusOne-Client': 'CataniaBus/2.2; https://github.com/AndreaGirlando',
        'X-BusOne-Use': 'personal',
    })
    try:
        with urllib.request.urlopen(request, timeout=25) as response:
            body = response.read(limit + 1)
            if len(body) > limit:
                raise ValueError('Risposta oltre il limite di verifica')
            return {'url': url, 'final_url': response.url, 'status': response.status,
                    'content_type': response.headers.get('Content-Type', ''),
                    'bytes': len(body)}, body
    except (urllib.error.URLError, TimeoutError, ValueError) as error:
        return {'url': url, 'error': str(error)}, b''


page, body = fetch('https://www.amts.ct.it/open-data')
report['sources'].append(page)
text = body.decode('utf-8', errors='replace')
(OUT / 'amts.html').write_text(text)
links = [urllib.parse.urljoin(page.get('final_url', page['url']), unescape(link))
         for link in re.findall(r'href\s*=\s*[\"\']([^\"\']+)', text, re.I)]
candidates = list(dict.fromkeys(link for link in links
                               if '.zip' in link.lower() and ('gtfs' in link.lower() or 'amts' in link.lower())))
report['static_candidates'] = candidates
for i, url in enumerate(candidates[:3]):
    item, data = fetch(url, 100_000_000)
    if data:
        try:
            with zipfile.ZipFile(io.BytesIO(data)) as archive:
                item['files'] = archive.namelist()
                (OUT / 'official-gtfs.zip').write_bytes(data)
                for name in ['agency.txt', 'calendar.txt', 'calendar_dates.txt', 'feed_info.txt']:
                    matches = [n for n in archive.namelist() if n.rsplit('/', 1)[-1] == name]
                    if matches:
                        with archive.open(matches[0]) as stream:
                            rows = csv.DictReader(io.TextIOWrapper(stream, encoding='utf-8-sig'))
                            item[name] = [row for _, row in zip(range(3), rows)]
        except zipfile.BadZipFile:
            item['error'] = 'La risposta non è un archivio ZIP'
    report['sources'].append(item)

for name, url in [
    ('busone', 'https://proxy.busone.app/amts/'),
    ('trip-updates', 'https://proxy.busone.app/amts/gtfs-rt/trip-updates.json'),
]:
    item, data = fetch(url)
    report['sources'].append(item)
    (OUT / f'{name}.txt').write_bytes(data)
    if name == 'trip-updates' and data:
        try:
            feed = json.loads(data)
            item['header'] = feed.get('header')
            item['entity_count'] = len(feed.get('entity', []))
            item['sample_entity'] = feed.get('entity', [None])[0] if feed.get('entity') else None
            stamp = int(feed.get('header', {}).get('timestamp', 0))
            fresh = [e['trip_update'] for e in feed.get('entity', [])
                     if 'trip_update' in e and -30 <= stamp - int(e['trip_update'].get('timestamp', 0)) <= 180]
            future = [s['arrival'] for u in fresh for s in u.get('stop_time_update', [])
                      if int(s.get('arrival', {}).get('time', 0)) >= stamp]
            item['quality'] = {
                'fresh_trip_updates': len(fresh), 'future_events': len(future),
                'uncertainty_at_most_120s': sum(int(e.get('uncertainty', 0)) <= 120 for e in future),
                'uncertainty_at_most_900s': sum(int(e.get('uncertainty', 0)) <= 900 for e in future),
            }
        except (ValueError, AttributeError):
            item['error'] = 'La risposta non è un oggetto JSON GTFS-Realtime'

(OUT / 'report.json').write_text(json.dumps(report, indent=2, ensure_ascii=False))
print(json.dumps(report, indent=2, ensure_ascii=False))

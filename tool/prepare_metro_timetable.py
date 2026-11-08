#!/usr/bin/env python3
"""Extract factual FCE departures and explicitly historical station offsets.

No FCEQuando code, estimates or measurements are copied. Review a changed PDF
before accepting a new source digest: table order is part of this parser contract.
"""
import csv
import hashlib
import io
import json
import re
import sys
import zipfile
from collections import Counter, defaultdict
from pathlib import Path
from pypdf import PdfReader

PDF_SHA = 'bacc7bccebeab558999552b0f23149f9f410c54d3955f8e170238dfff6ec8986'
PDF_URL = 'https://www.circumetnea.it/download/orario-metro/?wpdmdl=18207'
GTFS_URL = 'https://www.circumetnea.it/download/general-transit-feed-specification-fce-01-02-2025-28-02-2028/?wpdmdl=17798'


def seconds(value):
    h, m, *s = map(int, value.split(':'))
    return h * 3600 + m * 60 + (s[0] if s else 0)


def unwrap(values):
    result = []
    for value in values:
        stamp = seconds(value)
        if result and stamp < result[-1] % 86400:
            stamp += 86400
        elif result and result[-1] >= 86400:
            stamp += 86400
        if result and stamp <= result[-1]:
            raise ValueError('Departure order or PDF layout changed')
        result.append(stamp)
    return result


def build(pdf_path, gtfs_path):
    pdf = Path(pdf_path).read_bytes()
    if hashlib.sha256(pdf).hexdigest() != PDF_SHA:
        raise ValueError('New FCE PDF: review timetable layout and source digest before publishing')
    layout = PdfReader(io.BytesIO(pdf)).pages[0].extract_text(extraction_mode='layout')
    departures, arrivals = [], []
    for line in layout.splitlines():
        match = re.match(r'\s*(MONTE PO|STESICORO)\s+(PART\.|ARR\.)\s+(.*)', line)
        if match:
            times = re.findall(r'\b\d{2}:\d{2}\b', match[3])
            (departures if match[2] == 'PART.' else arrivals).append((match[1], unwrap(times)))
    if len(departures) != 16 or len(arrivals) != 16:
        raise ValueError('Expected all 16 departure and arrival rows')
    days = {key: {'stesicoro': [], 'montepo': []} for key in
            ['weekday', 'friday', 'saturday', 'sunday', 'holiday_weekday', 'holiday_late']}
    groups = ['weekday'] * 4 + ['friday'] * 4 + ['saturday'] * 2 + ['sunday'] * 2 + ['holiday_weekday'] * 2 + ['holiday_late'] * 2
    for (origin, times), (_, ends), group in zip(departures, arrivals, groups):
        if len(times) != len(ends) or any((b - a) % 86400 != 1200 for a, b in zip(times, ends)):
            raise ValueError('FCE published travel time is no longer 20 minutes')
        days[group]['stesicoro' if origin == 'MONTE PO' else 'montepo'].extend(times)
    for day in days.values():
        for values in day.values():
            if values != sorted(set(values)) or len(values) < 60:
                raise ValueError('Missing or duplicate timetable departures')
    gtfs_bytes = Path(gtfs_path).read_bytes()
    with zipfile.ZipFile(io.BytesIO(gtfs_bytes)) as archive:
        def rows(name):
            return list(csv.DictReader(io.StringIO(archive.read(name).decode('utf-8-sig'))))
        route_ids = {r['route_id'] for r in rows('routes.txt') if r['route_long_name'].strip().upper() == 'METROPOLITANA'}
        trips = {t['trip_id'] for t in rows('trips.txt') if t['route_id'] in route_ids}
        stops = {s['stop_id']: s for s in rows('stops.txt')}
        by_trip = defaultdict(list)
        for stop in rows('stop_times.txt'):
            if stop['trip_id'] in trips:
                by_trip[stop['trip_id']].append(stop)
        patterns = Counter()
        for trip in by_trip.values():
            trip.sort(key=lambda r: int(r['stop_sequence']))
            start = seconds(trip[0]['arrival_time'])
            patterns[tuple((r['stop_id'], seconds(r['arrival_time']) - start) for r in trip)] += 1
        if len(patterns) != 2 or any(len(p) != 12 or p[-1][1] != 1200 for p in patterns):
            raise ValueError('Review station offsets: expected two 12-station, 20-minute patterns')
        towards = {}
        for pattern in patterns:
            terminal = stops[pattern[-1][0]]['stop_name'].upper()
            towards['stesicoro' if terminal == 'STESICORO' else 'montepo'] = dict(pattern)
        forward = next(p for p in patterns if stops[p[-1][0]]['stop_name'].upper() == 'STESICORO')
        stations = [{'id': sid, 'name': stops[sid]['stop_name'].title().replace('Xxiii', 'XXIII'),
                     'stesicoro': towards['stesicoro'][sid], 'montepo': towards['montepo'][sid]} for sid, _ in forward]
        end = max(c['end_date'] for c in rows('calendar.txt'))
    return {'schema': 1, 'published_date': '2026-09-03', 'checked_date': '2026-11-08',
            'pdf_url': PDF_URL, 'pdf_sha256': PDF_SHA,
            'gtfs_url': GTFS_URL, 'gtfs_sha256': hashlib.sha256(gtfs_bytes).hexdigest(),
            'offsets_valid_until': end, 'stations': stations, 'days': days}


if __name__ == '__main__':
    result = build(sys.argv[1], sys.argv[2])
    target = Path(sys.argv[3])
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('FCE verified: 12 stations, 6 day types, both directions; historical offsets clearly marked:', result['offsets_valid_until'])

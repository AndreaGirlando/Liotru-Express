#!/usr/bin/env python3
"""Precarica la distribuzione ufficiale con retry, nel cache del wrapper.

Il wrapper verifica nuovamente lo stesso SHA-256: nessuna sostituzione di Gradle.
Utile sui runner dove il redirect GitHub della distribuzione può restituire 504.
"""
import hashlib
import os
from pathlib import Path
import re
import subprocess

properties = Path('android/gradle/wrapper/gradle-wrapper.properties').read_text()
url = re.search(r'^distributionUrl=(.+)$', properties, re.M)[1].replace('\\:', ':')
checksum = re.search(r'^distributionSha256Sum=(.+)$', properties, re.M)[1]
filename = url.rsplit('/', 1)[1]
# Gradle PathAssembler: unsigned MD5(url), written in radix 36.
number = int.from_bytes(hashlib.md5(url.encode(), usedforsecurity=False).digest(), 'big')
alphabet = '0123456789abcdefghijklmnopqrstuvwxyz'
cache_key = ''
while number:
    number, digit = divmod(number, 36)
    cache_key = alphabet[digit] + cache_key
root = Path(os.environ.get('GRADLE_USER_HOME', Path.home() / '.gradle'))
directory = root / 'wrapper' / 'dists' / filename.removesuffix('.zip') / cache_key
directory.mkdir(parents=True, exist_ok=True)
destination = directory / filename
if not destination.with_suffix('.zip.ok').exists():
    part = destination.with_suffix('.zip.download')
    subprocess.run(['curl', '--fail', '--location', '--retry', '4',
                    '--retry-all-errors', '--retry-delay', '3',
                    '--connect-timeout', '25', '--max-time', '120',
                    url, '-o', str(part)], check=True)
    digest = hashlib.file_digest(part.open('rb'), 'sha256').hexdigest()
    if digest != checksum:
        part.unlink()
        raise ValueError('Checksum della distribuzione Gradle non corrispondente')
    part.replace(destination)
print('Distribuzione Gradle ufficiale pronta, checksum SHA-256 verificato.')

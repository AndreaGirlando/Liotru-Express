#!/usr/bin/env python3
"""Precarica il compilatore ufficiale Kotlin usato dal progetto Android."""
import hashlib
from pathlib import Path
import subprocess
import tempfile

version = '2.1.0'
artifact = f'kotlin-compiler-embeddable-{version}'
checksum = 'c1b139a6f251c3b99e92befa326cb75d93a001d74c3ac601155a8cdb0d253783'
# SHA-256 computed from the Maven Central artifact, also cross-checked against
# its published SHA-1 988bf980588bbbcfa1ba19c1ffd7aa869b335a31.
base_url = f'https://repo.maven.apache.org/maven2/org/jetbrains/kotlin/kotlin-compiler-embeddable/{version}'
directory = Path.home() / '.m2/repository/org/jetbrains/kotlin/kotlin-compiler-embeddable' / version
directory.mkdir(parents=True, exist_ok=True)
jar = directory / f'{artifact}.jar'
result = subprocess.run(['curl', '--fail', '--location', '--retry', '1',
                         '--retry-all-errors', '--max-time', '120',
                         f'{base_url}/{artifact}.jar', '-o', str(jar)])
if result.returncode:
    with tempfile.TemporaryDirectory(prefix='catania_kotlin_') as temporary:
        subprocess.run(['gh', 'release', 'download', f'v{version}',
                        '--repo', 'JetBrains/kotlin', '--pattern', jar.name,
                        '--dir', temporary], check=True)
        (Path(temporary) / jar.name).replace(jar)
with jar.open('rb') as stream:
    actual = hashlib.file_digest(stream, 'sha256').hexdigest()
if actual != checksum:
    jar.unlink()
    raise ValueError('Checksum compilatore Kotlin non corrispondente')
subprocess.run(['curl', '--fail', '--location', '--retry', '3',
                '--max-time', '30', f'{base_url}/{artifact}.pom',
                '-o', str(directory / f'{artifact}.pom')], check=True)
print('Kotlin 2.1.0 ufficiale pronto; checksum SHA-256 verificato.')

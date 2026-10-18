#!/usr/bin/env python3
"""Read-only verification against the exact files supplied with the task."""
import argparse
import hashlib
import os
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--root', type=Path, default=Path(__file__).resolve().parents[3])
args = parser.parse_args()
manifest = Path(__file__).resolve().parents[1] / 'docs/original-files.sha256'
failures = []
count = 0
originals = set()
for line in manifest.read_text().splitlines():
    digest, name = line.split('  ', 1)
    source = args.root / name
    originals.add(name)
    if not source.is_file() or hashlib.sha256(source.read_bytes()).hexdigest() != digest:
        failures.append(name)
    count += 1
for directory, folders, files in os.walk(args.root):
    relative = Path(directory).relative_to(args.root)
    if relative == Path('apps'):
        folders[:] = [folder for folder in folders if folder != 'mobile']
    for filename in files:
        name = (relative / filename).as_posix()
        if name not in originals:
            failures.append(name + ' (unauthorized addition)')
if failures:
    print('CHANGED/MISSING: ' + ', '.join(failures))
    raise SystemExit(1)
print(f'PASS: {count} original files unchanged; only apps/mobile is an authorized addition.')

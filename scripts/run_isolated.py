#!/usr/bin/env python3
"""Launch the verified native binary from its otherwise empty directory."""
import json
import os
from pathlib import Path
from verify_isolation import ROOT, environment

report = json.loads((ROOT / 'evidence/isolation.json').read_text())
folder = Path(report['native_directory'])
binary = folder / 'libratrack'
if sorted(p.name for p in folder.iterdir()) != ['libratrack']:
    raise SystemExit('The verification directory must contain only libratrack.')
print('Working directory:', folder, flush=True)
print('Files: libratrack', flush=True)
print('Open http://localhost:8087/catalog — stop with Ctrl+C', flush=True)
os.chdir(folder)
os.execve(binary, [str(binary)], {**environment(), 'PORT': '8087', 'LISTEN_HOST': '127.0.0.1'})

#!/usr/bin/env python3
"""Verify native and Linux single-binary deployments without exposing credentials."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[1]

def environment():
    result = os.environ.copy()
    for line in (ROOT / '.env').read_text().splitlines():
        if '=' in line and not line.lstrip().startswith('#'):
            key, value = line.split('=', 1)
            result.setdefault(key, value)
    result['MIGRATIONS_PATH'] = ''
    result['COOKIE_SECURE'] = 'false'
    return result

def wait_for(base):
    for _ in range(100):
        try:
            with urllib.request.urlopen(base + '/health', timeout=1) as response:
                if response.status == 200:
                    return
        except (OSError, TimeoutError):
            time.sleep(.2)
    raise RuntimeError('isolated server did not become healthy')

def verify(base):
    checks = {}
    for path, marker in [('/catalog', b'book-list'), ('/static/css/style.css', b'.container'),
                         ('/static/js/htmx.min.js', b'htmx'), ('/static/js/app.js', b'htmx:beforeSwap'),
                         ('/web/books?q=Go', b'Learning Go')]:
        with urllib.request.urlopen(base + path, timeout=5) as response:
            body = response.read()
            assert response.status == 200 and marker in body, path
            if path.startswith('/static/'):
                assert body == (ROOT / 'web' / path.removeprefix('/')).read_bytes(), path
            if path.startswith('/web/'):
                assert b'<!DOCTYPE' not in body, path
            checks[path] = {'status': response.status, 'bytes': len(body), 'sha256': hashlib.sha256(body).hexdigest()}
    return checks

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--keep-container', action='store_true', help='keep verified container on localhost:8086')
    args = parser.parse_args()
    env = environment()
    (ROOT / 'bin').mkdir(exist_ok=True)
    for name, overrides in [('libratrack', {}), ('libratrack-linux', {'GOOS': 'linux', 'GOARCH': 'amd64'})]:
        subprocess.run(['go', 'build', '-trimpath', '-o', str(ROOT / 'bin' / name), './cmd/api'], cwd=ROOT,
                       env={**env, 'CGO_ENABLED': '0', **overrides}, check=True)
    native_dir = Path(tempfile.mkdtemp(prefix='verify-libratrack-', dir='/tmp'))
    shutil.copy2(ROOT / 'bin/libratrack', native_dir / 'libratrack')
    native_env = {**env, 'PORT': '8087', 'LISTEN_HOST': '127.0.0.1'}
    with tempfile.TemporaryFile() as logs:
        process = subprocess.Popen([str(native_dir / 'libratrack')], cwd=native_dir, env=native_env, stdout=logs, stderr=logs)
        try:
            wait_for('http://127.0.0.1:8087')
            native_checks = verify('http://127.0.0.1:8087')
            assert sorted(p.name for p in native_dir.iterdir()) == ['libratrack']
        finally:
            process.terminate()
            process.wait(timeout=10)
    context = Path(tempfile.mkdtemp(prefix='libratrack-container-', dir='/tmp'))
    shutil.copy2(ROOT / 'bin/libratrack-linux', context / 'libratrack')
    (context / 'Dockerfile').write_text('FROM scratch\nCOPY libratrack /libratrack\nUSER 65532:65532\nENTRYPOINT ["/libratrack"]\n')
    subprocess.run(['docker', 'build', '-t', 'libratrack10-isolated:local', str(context)], check=True)
    container_env = {**env, 'DATABASE_URL': '', 'PORT': '8085', 'LISTEN_HOST': '0.0.0.0', 'POSTGRES_HOST': 'host.docker.internal'}
    # Explicit env names make Docker read values from the process environment, not command-line arguments.
    existing = subprocess.run(['docker', 'inspect', '--format', '{{index .Config.Labels "org.libratrack.lesson10.isolation"}}', 'libratrack10-isolated'], capture_output=True, text=True)
    if existing.returncode == 0:
        if existing.stdout.strip() != 'true':
            raise RuntimeError('container name already exists without the isolation-test label')
        subprocess.run(['docker', 'rm', '-f', 'libratrack10-isolated'], check=True, stdout=subprocess.DEVNULL)
    command = ['docker', 'run', '-d', '--name', 'libratrack10-isolated', '--label', 'org.libratrack.lesson10.isolation=true', '--read-only', '--cap-drop=ALL',
               '--security-opt=no-new-privileges', '-p', '127.0.0.1:8086:8085']
    for key in ['DATABASE_URL', 'POSTGRES_HOST', 'POSTGRES_PORT', 'POSTGRES_DB', 'APP_DB_USER', 'APP_DB_PASSWORD',
                'JWT_SECRET', 'COOKIE_SECURE', 'MIGRATIONS_PATH', 'PORT', 'LISTEN_HOST']:
        command += ['-e', key]
    command += ['libratrack10-isolated:local']
    subprocess.run(command, env=container_env, check=True, stdout=subprocess.DEVNULL)
    success = False
    try:
        wait_for('http://127.0.0.1:8086')
        linux_checks = verify('http://127.0.0.1:8086')
        details = json.loads(subprocess.check_output(['docker', 'inspect', 'libratrack10-isolated'], text=True))[0]
        assert not details['Mounts']
        assert details['HostConfig']['ReadonlyRootfs']
        report = {'native_directory': str(native_dir), 'native_files': ['libratrack'], 'native': native_checks,
                  'container': {'image': 'libratrack10-isolated:local', 'mounts': [], 'read_only': True,
                                'non_root': details['Config']['User'], 'checks': linux_checks},
                  'note': 'PostgreSQL and secret environment configuration remain external. No UI or SQL files are mounted.'}
        target = ROOT / 'evidence/isolation.json'
        target.parent.mkdir(exist_ok=True)
        target.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
        print('PASS: native binary in', native_dir, '(only libratrack)')
        print('PASS: scratch container, read-only filesystem, non-root, no mounted files')
        print('PASS: catalog, CSS, HTMX, application JS and search in both environments')
        print('Report:', target)
        success = True
    finally:
        if not (success and args.keep_container):
            subprocess.run(['docker', 'rm', '-f', 'libratrack10-isolated'], check=True, stdout=subprocess.DEVNULL)
    if args.keep_container:
        print('Container remains available at http://localhost:8086/catalog')

if __name__ == '__main__':
    main()

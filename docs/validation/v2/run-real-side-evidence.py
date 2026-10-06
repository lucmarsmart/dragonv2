"""Record current real-slope landing with the unchanged parent driver and side camera."""
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/validation/v2'
paths = list(json.loads((OUT / 'launcher-final-run.json').read_text())['source_files_sha256_after'])
def hashes():
    return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
if subprocess.run(['pgrep', '-x', 'Godot'], capture_output=True).returncode == 0:
    raise SystemExit('Another Godot is active')
before = hashes()
command = [str(ROOT / 'tools/godot.sh'), '--path', str(ROOT), '--windowed', '--resolution', '1280x720',
           '--write-movie', str(OUT / 'anatomy-real-final.avi'), '--fixed-fps', '60',
           '--script', 'res://scripts/test_dragon_anatomy.gd', '--', '--real-terrain',
           '--body-terrain', '--capture-real-motion']
started = datetime.now(timezone.utc).isoformat()
log = OUT / 'anatomy-real-motion-final-metal.log'
with log.open('w') as stream:
    result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
after = hashes()
errors = re.findall(r'^.*(?:SCRIPT ERROR|SHADER ERROR|^ERROR:|^FAIL ).*$', log.read_text(), re.MULTILINE)
movie = OUT / 'anatomy-real-final.avi'
fresh = movie.is_file() and movie.stat().st_mtime >= datetime.fromisoformat(started).timestamp()
data = {'command': command, 'started_utc': started, 'finished_utc': datetime.now(timezone.utc).isoformat(),
        'returncode': result.returncode, 'source_files_sha256_before': before,
        'source_files_sha256_after': after, 'source_files_unchanged': before == after,
        'engine_errors': errors, 'movie_fresh': fresh,
        'passed': result.returncode == 0 and before == after and not errors and fresh,
        'scope': 'Original real-terrain regression, actual side camera. MovieMaker is visual evidence, never FPS.'}
(OUT / 'anatomy-real-side-final-run.json').write_text(json.dumps(data, indent=2) + '\n')
print(json.dumps({k: data[k] for k in ['returncode', 'passed', 'source_files_unchanged', 'engine_errors']}))
raise SystemExit(0 if data['passed'] else 1)

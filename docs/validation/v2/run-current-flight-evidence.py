"""Capture the current 20-second gliding contract with the actual native renderer."""
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
V = ROOT / 'docs/validation/v2'
paths = list(json.loads((V / 'launcher-final-run.json').read_text())['source_files_sha256_after'])
def hashes(): return {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in paths}
if subprocess.run(['pgrep', '-x', 'Godot'], capture_output=True).returncode == 0:
    raise SystemExit('Another Godot is active')
before = hashes()
started = datetime.now(timezone.utc).isoformat()
command = [str(ROOT / 'tools/godot.sh'), '--path', str(ROOT), '--windowed', '--resolution', '1280x720',
    '--write-movie', str(V / 'anatomy-flight-final.avi'), '--fixed-fps', '60',
    '--script', 'res://scripts/test_dragon_anatomy.gd', '--', '--capture']
log = V / 'anatomy-flight-native-final.log'
with log.open('w') as stream:
    result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
after = hashes()
errors = re.findall(r'^.*(?:SCRIPT ERROR|SHADER ERROR|^ERROR:|^FAIL ).*$', log.read_text(), re.MULTILINE)
names = ['anatomy-glide-0000.png', 'anatomy-glide-0420.png', 'anatomy-glide-0840.png']
fresh = {p: (V / p).is_file() and (V / p).stat().st_mtime >= datetime.fromisoformat(started).timestamp() for p in names}
report = {'command': command, 'started_utc': started, 'finished_utc': datetime.now(timezone.utc).isoformat(),
    'returncode': result.returncode, 'source_files_sha256_before': before, 'source_files_sha256_after': after,
    'source_files_unchanged': before == after, 'engine_errors': errors, 'fresh_glide_images': fresh,
    'scope': 'Native full parent anatomy assertions plus actual 20-second neutral glide and three camera views. MovieMaker and Skin instrumentation invalidate FPS.',
    'passed': result.returncode == 0 and before == after and not errors and all(fresh.values())}
(V / 'anatomy-flight-native-final-run.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: report[k] for k in ['returncode', 'passed', 'engine_errors', 'fresh_glide_images']}))
raise SystemExit(0 if report['passed'] else 1)

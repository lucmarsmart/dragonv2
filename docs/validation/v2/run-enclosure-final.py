"""Recheck current original Skin and emitted collision volumes on a frozen runtime."""
import argparse
import gzip
import hashlib
import json
import os
import re
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
V = ROOT / 'docs/validation/v2'
parser = argparse.ArgumentParser()
parser.add_argument('additional_poses', nargs='+', help='Stable construction/holdout files from the anatomy handoff')
args = parser.parse_args()
paths = list(json.loads((V / 'launcher-final-run.json').read_text())['source_files_sha256_after'])
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def hashes(): return {p: sha(ROOT / p) for p in paths}
if subprocess.run(['pgrep', '-x', 'Godot'], capture_output=True).returncode == 0:
    raise SystemExit('Another Godot is active; coordinate the geometry check first.')
before = hashes()
started = datetime.now(timezone.utc).isoformat()
runs = []
def run(name, command, env=None):
    log = V / (name + '.log')
    with log.open('w') as stream:
        result = subprocess.run(command, cwd=ROOT, env=env, stdout=stream, stderr=subprocess.STDOUT)
    errors = re.findall(r'^.*(?:SCRIPT ERROR|SHADER ERROR|^ERROR:|^FAIL ).*$', log.read_text(), re.MULTILINE)
    entry = {'name': name, 'command': command, 'returncode': result.returncode, 'errors': errors, 'log': log.name}
    runs.append(entry)
    print(json.dumps(entry), flush=True)
    if result.returncode or errors:
        raise RuntimeError('Geometry validation failed: ' + name)
try:
    run('anatomy-stable-parent-holdout-final', [str(ROOT / 'tools/godot.sh'), '--headless', '--path', str(ROOT),
        '--fixed-fps', '60', '--script', 'res://scripts/test_dragon_anatomy.gd', '--', '--enclosure-holdout', '--holdout-second'])
    independent = V / 'anatomy-enclosure-holdout2-independent.json'
    shutil.copy2(V / 'anatomy-holdout-full-skin.json', independent)
    inputs = [V / 'anatomy-full-skin.json', V / 'anatomy-real-full-skin.json', independent]
    inputs += [ROOT / p for p in args.additional_poses]
    combined = {}
    sources = []
    for i, path in enumerate(inputs):
        opener = gzip.open if path.suffix == '.gz' else open
        with opener(path, 'rt') as stream: data = json.load(stream)
        if any(pose.get('wing_partition') != 'rig-root96-120-boundary-v1' for pose in data.values()):
            raise RuntimeError('Historical/missing wing partition: ' + path.name)
        for label, pose in data.items(): combined[str(i) + ':' + path.stem + ':' + label] = pose
        sources.append({'file': str(path.relative_to(ROOT)), 'sha256': sha(path), 'poses': len(data)})
    combined_path = V / 'anatomy-stable-current-all-poses.json.gz'
    with gzip.open(combined_path, 'wt') as stream: json.dump(combined, stream, separators=(',', ':'))
    environment = os.environ.copy()
    environment['PYTHONPATH'] = '/tmp/dragon-anatomy-python'
    environment['OPENBLAS_NUM_THREADS'] = '1'
    run('anatomy-stable-current-selection-final', ['python3', str(V / 'anatomy-hull-verifier.py'), str(combined_path)], environment)
    run('anatomy-stable-current-runtime-final', ['python3', str(V / 'anatomy-hull-verifier.py'), str(combined_path), '--runtime-hulls'], environment)
    run('anatomy-body-partition-current-final', ['python3', str(V / 'anatomy-body-partition-verifier.py'), str(V / 'anatomy-body-partition-skin.json')], environment)
    run('anatomy-egg-current-final', ['python3', str(V / 'anatomy-egg-hull-verifier.py')], environment)
    run('anatomy-affine-current-final', ['python3', str(V / 'anatomy-affine-verifier.py')], environment)
    passed = before == hashes()
except Exception as exc:
    passed = False
    failure = str(exc)
else:
    failure = None
receipt = {'started_utc': started, 'finished_utc': datetime.now(timezone.utc).isoformat(), 'runs': runs,
    'source_files_sha256_before': before, 'source_files_sha256_after': hashes(), 'source_files_unchanged': before == hashes(),
    'pose_inputs': locals().get('sources', []), 'combined_poses': len(locals().get('combined', {})),
    'combined_file': locals().get('combined_path', V).name,
    'combined_sha256': sha(combined_path) if 'combined_path' in locals() and combined_path.exists() else None,
    'failure': failure, 'passed': passed,
    'scope': 'Finite current partition only. Parent second holdout is regenerated after selection has been frozen and is never used to select vertex IDs.'}
(V / 'anatomy-enclosure-final-run.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps({'passed': passed, 'poses': receipt['combined_poses'], 'failure': failure}))
raise SystemExit(0 if passed else 1)

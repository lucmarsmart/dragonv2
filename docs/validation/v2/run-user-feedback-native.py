"""Capture user regressions with the native renderer, never measure FPS."""
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/validation/v2'

def hashes():
    files = [ROOT / 'project.godot', ROOT / 'scenes/main.tscn']
    files += sorted((ROOT / 'scripts').rglob('*.gd'))
    files += sorted((ROOT / 'scripts').glob('dragon_*.json'))
    files += sorted((ROOT / 'shaders').glob('*.gdshader'))
    files += sorted(p for p in (ROOT / 'assets').rglob('*.import') if 'source' not in p.parts)
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}

runs = []
for name, driver, arguments, prefixes, minimum_captures, report_name in [
    ('descent', 'scripts/anatomy_descent_compact_repro.gd', ['--capture'], ['anatomy-descent-compact-'], 3, 'anatomy-descent-compact-candidate.json'),
    ('ground-escape', 'scripts/combat/test_ground_escape.gd', ['--capture-ground-escape'], ['ground-escape-'], 3, 'ground-escape-trace.json'),
    ('mouth', 'scripts/anatomy_mouth_repro.gd', ['--capture'], ['anatomy-mouth-'], 40, 'anatomy-mouth-report.json'),
    ('terrain-player-escape-500-450', 'scripts/combat/test_terrain_player_escape.gd', ['--x=500', '--z=450', '--capture-ground-escape'], ['terrain-player-escape-500-450-'], 3, 'terrain-player-escape-500-450.json'),
    ('terrain-player-escape-850-130', 'scripts/combat/test_terrain_player_escape.gd', ['--x=850', '--z=130', '--capture-ground-escape'], ['terrain-player-escape-850-130-'], 3, 'terrain-player-escape-850-130.json'),
    ('terrain-player-escape--450-220', 'scripts/combat/test_terrain_player_escape.gd', ['--x=-450', '--z=220', '--capture-ground-escape'], ['terrain-player-escape--450-220-'], 3, 'terrain-player-escape--450-220.json'),
    ('air-contact-escape', 'scripts/combat/test_air_contact_escape.gd', [], [], 0, 'air-contact-escape.json'),
    ('player-aim-feedback', 'scripts/combat/test_player_aim_feedback.gd', [], ['player-aim-feedback-'], 2, 'player-aim-feedback.json'),
]:
    if subprocess.run(['pgrep', '-x', 'Godot'], capture_output=True).returncode == 0:
        raise SystemExit('Another Godot is active; coordinate the native regression first.')
    before = hashes()
    started = datetime.now(timezone.utc)
    command = [str(ROOT / 'tools/godot.sh'), '--path', str(ROOT), '--windowed',
               '--resolution', '1280x720', '--fixed-fps', '60', '--script', 'res://' + driver]
    if arguments:
        command += ['--'] + arguments
    log = OUT / (name + '-native-final.log')
    print('Starting native regression:', name, flush=True)
    with log.open('w') as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    after = hashes()
    errors = re.findall(r'^.*(?:SCRIPT ERROR|SHADER ERROR|^ERROR:|^FAIL ).*$',
                        log.read_text(errors='replace'), re.MULTILINE)
    captures = [p for p in OUT.glob('*.png') if any(p.name.startswith(s) for s in prefixes)
                and p.stat().st_mtime >= started.timestamp()]
    report_path = OUT / report_name
    report_fresh = report_path.is_file() and report_path.stat().st_mtime >= started.timestamp()
    report = json.loads(report_path.read_text()) if report_fresh else {}
    report_passed = report_fresh and 'failures' in report and not report['failures'] and report.get('pass', True)
    passed = result.returncode == 0 and before == after and not errors and len(captures) >= minimum_captures and report_passed
    entry = {'name': name, 'command': command, 'started_utc': started.isoformat(),
             'finished_utc': datetime.now(timezone.utc).isoformat(), 'returncode': result.returncode,
             'source_files_sha256_before': before, 'source_files_sha256_after': after,
             'source_files_unchanged': before == after, 'engine_errors': errors,
             'captures_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in captures},
             'minimum_captures': minimum_captures, 'report': report_name,
             'report_sha256': hashlib.sha256(report_path.read_bytes()).hexdigest() if report_fresh else None,
             'report_fresh': report_fresh, 'report_passed': report_passed,
             'log': log.name, 'passed': passed,
             'scope': 'Native visual/functional evidence at fixed 60 Hz. Instrumented Skin probes and PNG readback invalidate FPS measurements.'}
    runs.append(entry)
    (OUT / 'user-feedback-native-run.json').write_text(json.dumps({'runs': runs, 'passed': all(r['passed'] for r in runs)}, indent=2) + '\n')
    print(json.dumps({k: entry[k] for k in ['name', 'returncode', 'passed', 'engine_errors']}), flush=True)
    if not passed:
        raise SystemExit(1)

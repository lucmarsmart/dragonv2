"""Run the real locomotion contract natively with camera-only evidence subclass."""
import hashlib,json,re,shutil,subprocess
from datetime import datetime,timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]; V=ROOT/'docs/validation/v2'
paths=list(json.loads((V/'launcher-final-run.json').read_text())['source_files_sha256_after'])+['docs/validation/v2/capture-bank-contract.gd']
def hashes(): return {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in paths}
if subprocess.run(['pgrep','-x','Godot'],capture_output=True).returncode==0: raise SystemExit('Another Godot active')
before=hashes(); started=datetime.now(timezone.utc).isoformat()
shutil.copy2(V/'anatomy-locomotion-contract.json',V/'anatomy-locomotion-contract-headless.json')
cmd=[str(ROOT/'tools/godot.sh'),'--path',str(ROOT),'--windowed','--resolution','1280x720','--fixed-fps','60','--script','res://docs/validation/v2/capture-bank-contract.gd','--','--locomotion-contract']
log=V/'anatomy-bank-native.log'
with log.open('w') as stream: result=subprocess.run(cmd,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
after=hashes(); errors=re.findall(r'^.*(?:SCRIPT ERROR|SHADER ERROR|^ERROR:|^FAIL ).*$',log.read_text(),re.MULTILINE)
shutil.copy2(V/'anatomy-locomotion-contract.json',V/'anatomy-locomotion-contract-native.json')
native_data=json.loads((V/'anatomy-locomotion-contract-native.json').read_text())
native_data['scope']='Native60Hz finite sequences with unchanged parent assertions and camera-only rendered captures; not an FPS benchmark.'
(V/'anatomy-locomotion-contract-native.json').write_text(json.dumps(native_data,indent=2)+'\n')
shutil.copy2(V/'anatomy-locomotion-contract-headless.json',V/'anatomy-locomotion-contract.json')
images={name:(V/name).is_file() and (V/name).stat().st_mtime>=datetime.fromisoformat(started).timestamp() for name in ['anatomy-bank-left_turn.png','anatomy-bank-left_release.png','anatomy-bank-right_turn.png','anatomy-bank-right_release.png']}
report={'command':cmd,'started_utc':started,'finished_utc':datetime.now(timezone.utc).isoformat(),'returncode':result.returncode,'source_files_sha256_before':before,'source_files_sha256_after':after,'source_files_unchanged':before==after,'engine_errors':errors,'fresh_rendered_images':images,'scope':'Native1280x720 camera-only subclass, unchanged parent assertions/controls. No FPS claim. Original headless report preserved.','passed':result.returncode==0 and before==after and not errors and all(images.values())}
(V/'anatomy-bank-native-run.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['returncode','passed','engine_errors','fresh_rendered_images']}))
raise SystemExit(0 if report['passed'] else 1)

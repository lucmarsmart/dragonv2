"""Capture landscape views with the final native renderer and bind their sources."""
import hashlib,json,re,subprocess
from datetime import datetime,timezone
from pathlib import Path
R=Path(__file__).resolve().parents[3];V=R/'docs/validation/v2'
paths=list(json.loads((V/'launcher-final-run.json').read_text())['source_files_sha256_after'])
def hashes():return {p:hashlib.sha256((R/p).read_bytes()).hexdigest() for p in paths}
if subprocess.run(['pgrep','-x','Godot'],capture_output=True).returncode==0:raise SystemExit('Another Godot is active')
before=hashes();started=datetime.now(timezone.utc)
command=[str(R/'tools/godot.sh'),'--path',str(R),'--windowed','--resolution','1280x720','--fixed-fps','60','--script','res://scripts/capture_siege_environment.gd']
log=V/'environment-native-final.log'
with log.open('w') as stream:result=subprocess.run(command,cwd=R,stdout=stream,stderr=subprocess.STDOUT)
after=hashes();errors=re.findall(r'^.*(?:SCRIPT ERROR|SHADER ERROR|^ERROR:).*$',log.read_text(),re.MULTILINE)
names=['environment-'+n+'.png' for n in ['fortress','fortress-air','river','river-close','mountain','pine','nest-captive','nest-free']]
fresh=all((V/n).is_file() and (V/n).stat().st_mtime>=started.timestamp() for n in names)
report={'command':command,'started_utc':started.isoformat(),'finished_utc':datetime.now(timezone.utc).isoformat(),'returncode':result.returncode,'source_files_sha256_before':before,'source_files_sha256_after':after,'source_files_unchanged':before==after,'engine_errors':errors,'captures_fresh':fresh,'captures_sha256':{n:hashlib.sha256((V/n).read_bytes()).hexdigest() for n in names},'scope':'Native landscape views, no FPS measurement. Scene construction fixture retains production terrain/environment.','passed':result.returncode==0 and before==after and not errors and fresh}
(V/'environment-native-final-run.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['returncode','passed','captures_fresh','engine_errors']}))
raise SystemExit(0 if report['passed'] else 1)

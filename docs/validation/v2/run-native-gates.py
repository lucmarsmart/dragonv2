"""Run the final native gates sequentially and bind each result to its sources."""
import argparse
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/validation/v2"
REPORT = OUT / "native-gates-run.json"
def source_hashes():
    sources = [ROOT / "project.godot", ROOT / "scenes/main.tscn"]
    sources += sorted((ROOT / "scripts").rglob("*.gd"))
    sources += sorted((ROOT / "scripts").glob("dragon_*.json"))
    sources += sorted((ROOT / "shaders").glob("*.gdshader"))
    sources += sorted(p for p in (ROOT / "assets").rglob("*.import")
                      if "source" not in p.parts)
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sources}


gates = [
    ("ui", "scripts/combat/capture_siege_ui.gd", "ui-native-final.log", True),
    ("combat", "scripts/combat/test_siege.gd", "combat-native-final.log", True),
    ("performance", "scripts/combat/benchmark_siege.gd", "combat-performance-final.log", False),
]
parser = argparse.ArgumentParser()
parser.add_argument("--only", choices=[g[0] for g in gates])
selected = parser.parse_args().only
report = (json.loads(REPORT.read_text()) if selected and REPORT.exists()
          else {"started_utc": datetime.now(timezone.utc).isoformat(), "gates": []})
if selected:
    report["gates"] = [g for g in report["gates"] if g["name"] != selected]
    gates = [g for g in gates if g[0] == selected]
for name, script, log_name, fixed in gates:
    active = subprocess.run(["pgrep", "-x", "Godot"], capture_output=True, text=True)
    if active.returncode == 0:
        raise SystemExit("Another Godot process is active; coordinate the native gate first.")
    before = source_hashes()
    command = [str(ROOT / "tools/godot.sh"), "--path", str(ROOT), "--windowed",
               "--resolution", "1280x720"]
    if fixed:
        command += ["--fixed-fps", "60"]
    command += ["--script", "res://" + script]
    started = datetime.now(timezone.utc).isoformat()
    print("Starting native gate:", name, flush=True)
    with (OUT / log_name).open("w") as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    after = source_hashes()
    changed = sorted(p for p in before.keys() | after.keys()
                     if before.get(p) != after.get(p))
    log = (OUT / log_name).read_text(errors="replace")
    errors = re.findall(r"^.*(?:SCRIPT ERROR|SHADER ERROR|^ERROR:).*$", log, re.MULTILINE)
    entry = {"name": name, "command": command, "started_utc": started,
             "finished_utc": datetime.now(timezone.utc).isoformat(),
             "returncode": result.returncode, "log": log_name,
             "source_files_sha256": before, "source_files_unchanged": not changed,
             "changed_sources": changed, "engine_errors": errors,
             "passed": result.returncode == 0 and not changed and not errors}
    report["gates"].append(entry)
    report["passed"] = all(g["passed"] for g in report["gates"])
    REPORT.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: entry[k] for k in ["name", "returncode", "passed", "changed_sources", "engine_errors"]}), flush=True)
    if not entry["passed"]:
        raise SystemExit(1)

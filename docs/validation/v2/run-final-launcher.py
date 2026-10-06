"""Run the delivered launcher and bind its result to runtime/import sources."""
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/validation/v2"


def source_hashes():
    files = [ROOT / p for p in ("project.godot", "scenes/main.tscn",
             "VALIDAR_DRAGON.command", "JUGAR_DRAGON.command", "tools/godot.sh")]
    files += sorted((ROOT / "scripts").rglob("*.gd"))
    files += sorted((ROOT / "scripts").glob("dragon_*.json"))
    files += sorted((ROOT / "shaders").glob("*.gdshader"))
    files += sorted(p for p in (ROOT / "assets").rglob("*.import")
                    if "source" not in p.parts)
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in files}


if subprocess.run(["pgrep", "-x", "Godot"], capture_output=True).returncode == 0:
    raise SystemExit("Another Godot process is active; coordinate validation first.")
before = source_hashes()
started = datetime.now(timezone.utc).isoformat()
command = [str(ROOT / "VALIDAR_DRAGON.command")]
log_path = OUT / "launcher-final.log"
with log_path.open("w") as stream:
    result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
after = source_hashes()
changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
log = log_path.read_text(errors="replace")
errors = re.findall(r"^.*(?:SCRIPT ERROR|SHADER ERROR|^ERROR:).*$", log, re.MULTILINE)
receipt = {"command": command, "started_utc": started,
           "finished_utc": datetime.now(timezone.utc).isoformat(),
           "returncode": result.returncode, "log": log_path.name,
           "source_files_sha256_before": before, "source_files_sha256_after": after,
           "source_files_unchanged": not changed, "changed_sources": changed,
           "engine_errors": errors,
           "passed": result.returncode == 0 and not changed and not errors}
(OUT / "launcher-final-run.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps({k: receipt[k] for k in ("returncode", "passed", "changed_sources", "engine_errors")}))
raise SystemExit(0 if receipt["passed"] else 1)

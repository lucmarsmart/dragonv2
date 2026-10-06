"""Validate the actual native mission separately from its MovieMaker recording."""
import argparse
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/validation/v2"
parser = argparse.ArgumentParser()
parser.add_argument("--movie", action="store_true")
parser.add_argument("--no-capture", action="store_true")
arguments = parser.parse_args()
movie = arguments.movie
no_capture = arguments.no_capture
if movie and no_capture:
    raise SystemExit("Movie evidence and capture-free performance are separate runs.")
tag = "metal" if movie else "native"


def sources():
    files = [ROOT / "project.godot", ROOT / "scenes/main.tscn"]
    files += sorted((ROOT / "scripts").rglob("*.gd"))
    files += sorted((ROOT / "scripts").glob("dragon_*.json"))
    files += sorted((ROOT / "shaders").glob("*.gdshader"))
    files += sorted(p for p in (ROOT / "assets").rglob("*.import")
                    if "source" not in p.parts)
    if no_capture:
        files.append(OUT / "playthrough-without-capture.gd")
    if movie:
        files.append(OUT / "playthrough-movie-evidence.gd")
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in files}


if subprocess.run(["pgrep", "-x", "Godot"], capture_output=True).returncode == 0:
    raise SystemExit("Another Godot process is active; coordinate the native mission first.")
before = sources()
started = datetime.now(timezone.utc).isoformat()
command = [str(ROOT / "tools/godot.sh"), "--path", str(ROOT), "--windowed",
           "--resolution", "1280x720"]
if movie:
    command += ["--write-movie", str(OUT / "playthrough-metal.avi"), "--fixed-fps", "60"]
command += ["--script", "res://docs/validation/v2/playthrough-without-capture.gd"
            if no_capture else "res://docs/validation/v2/playthrough-movie-evidence.gd"
            if movie else "res://scripts/combat/play_siege_validation.gd"]
log_path = OUT / f"playthrough-{tag}-final.log"
with log_path.open("w") as stream:
    result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
after = sources()
changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
errors = re.findall(r"^.*(?:SCRIPT ERROR|SHADER ERROR|^ERROR:).*$",
                    log_path.read_text(errors="replace"), re.MULTILINE)
report_path = OUT / f"playthrough-{tag}-report.json"
report = json.loads(report_path.read_text())
report_current = (report_path.stat().st_mtime >= datetime.fromisoformat(started).timestamp()
                  and all(before.get(path) == sha for path, sha
                          in report.get("runtime_sources_sha256", {}).items())
                  and bool(report.get("runtime_sources_sha256")))
movie_classification_ok = report["performance"]["movie_maker_enabled"] == movie
gameplay_ok = (report_current and movie_classification_ok and report["pass"] and report["phase"] == 5 and report["start_via_enter"]
               and report["phase_sequence"] == [1, 2, 3, 4, 5]
               and report["runtime_sources_unchanged_at_finish"]
               and report["runtime_state_overrides"] == 0
               and report["teleports_after_start"] == 0
               and report["damage_api_calls"] == 0)
performance = report["performance"]
bad_groups = {k: v for k, v in performance["by_phase_and_locomotion"].items()
              if v["frames"] >= 60 and not v["reference_budget_met"]}
performance_ok = (None if movie else performance["valid_runtime_fps_measurement"]
                  and performance["reference_budget_met"] and not bad_groups)
receipt = {"command": command, "started_utc": started,
           "finished_utc": datetime.now(timezone.utc).isoformat(),
           "returncode": result.returncode, "log": log_path.name,
           "source_files_sha256_before": before, "source_files_sha256_after": after,
           "source_files_unchanged": not changed, "changed_sources": changed,
           "engine_errors": errors, "gameplay_passed": gameplay_ok,
           "report_current_and_source_bound": report_current,
           "movie_classification_correct": movie_classification_ok,
           "raw_report_sha256": hashlib.sha256(report_path.read_bytes()).hexdigest(),
           "performance_passed": performance_ok, "performance_bad_groups": bad_groups,
           "capture_free_measurement": no_capture,
           "passed": result.returncode == 0 and not changed and not errors
                     and gameplay_ok and (movie or performance_ok)}
(OUT / f"playthrough-{tag}-final-run.json").write_text(json.dumps(receipt, indent=2) + "\n")
print(json.dumps({k: receipt[k] for k in ("returncode", "passed", "gameplay_passed",
      "performance_passed", "changed_sources", "engine_errors", "performance_bad_groups")}))
raise SystemExit(0 if receipt["passed"] else 1)

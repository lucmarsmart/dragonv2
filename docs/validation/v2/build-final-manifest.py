"""Hash the delivered runtime and the recorded evidence; never include user files."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/validation/v2/final-manifest.json"


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def record(path):
    return {"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size,
            "sha256": digest(path)}


runtime = [ROOT / p for p in ["project.godot", "scenes/main.tscn",
           "JUGAR_DRAGON.command", "VALIDAR_DRAGON.command", "tools/godot.sh"]]
runtime += sorted((ROOT / "scripts").rglob("*.gd"))
runtime += sorted((ROOT / "scripts").glob("dragon_*.json"))
runtime += sorted((ROOT / "shaders").glob("*.gdshader"))
assets = []
for directory in ["assets"]:
    assets += [p for p in (ROOT / directory).rglob("*") if p.is_file()
               and "source" not in p.parts
               and p.suffix.lower() in {".glb", ".gltf", ".bin", ".png", ".jpg", ".jpeg"}]
proof = [p for p in (ROOT / "docs/validation/v2").rglob("*")
         if p.is_file() and p != OUT and p.suffix in {".png", ".mp4", ".log", ".json", ".jsonl", ".gz"}
         and not p.name.startswith("c3-") and "baseline" not in p.name
         and p.name != "review-snapshot.json"]
proof += list((ROOT / "tests/artifacts/siege-assets").glob("*.png"))
data = {"generated_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "Local runtime, asset import configuration and recorded evidence. Historical failures retained. No user PDF, source archives, AVI, .godot binary cache or audit output included.",
        "runtime": [record(p) for p in sorted(set(runtime))],
        "asset_import_settings": [record(p) for p in sorted((ROOT / "assets").rglob("*.import"))
                                  if "source" not in p.parts],
        "assets": [record(p) for p in sorted(set(assets))],
        "validation_helpers": [record(p) for p in sorted((ROOT / "docs/validation/v2").glob("*"))
                               if p.is_file() and p.suffix in {".py", ".gd"}],
        "evidence": [record(p) for p in sorted(set(proof))]}
OUT.write_text(json.dumps(data, indent=2) + "\n")
print(json.dumps({"manifest": str(OUT), "runtime_files": len(data["runtime"]),
                  "asset_files": len(data["assets"]), "evidence_files": len(data["evidence"])}))

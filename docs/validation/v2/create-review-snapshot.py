"""Create a local immutable audit commit without touching HEAD or the user's index."""
import json
import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
BASE = "161070425ce3dbd3905487d48901826fde76c59d"
PREFIXES = ["assets/characters", "assets/siege", "assets/environment", "shaders",
            "scripts/combat", "docs/plans", "docs/validation/v2", "tests/artifacts/siege-assets", "tools"]
FILES = ["project.godot", "scenes/main.tscn", "README.md", "JUGAR_DRAGON.command", "VALIDAR_DRAGON.command",
         "assets/LICENSES.md", "docs/references-v2.md", "docs/assets-siege.md",
         "docs/anatomy-reference.md",
         "docs/validation/.gdignore", "tests/artifacts/.gdignore"]
FILES += [str(p.relative_to(ROOT)) for p in (ROOT / "scripts").glob("dragon_*")
          if p.suffix in {".gd", ".json"}]
FILES += ["scripts/flight_camera.gd", "scripts/hud.gd", "scripts/terrain.gd", "scripts/scenery_collisions.gd",
          "scripts/siege_environment.gd", "scripts/test_dragon_acceptance.gd", "scripts/test_dragon_anatomy.gd",
          "scripts/test_camera_surfaces.gd",
          "scripts/test_dragon_biomechanics.gd",
          "scripts/anatomy_descent_compact_repro.gd", "scripts/anatomy_mouth_repro.gd",
          "scripts/verify_siege_environment.gd", "scripts/capture_siege_environment.gd",
          "scripts/profile_siege_environment.gd", "scripts/generate_environment_foliage.py", "scripts/anatomy_profile_rescue.gd", "scripts/anatomy_profile_native.gd", "scripts/anatomy_profile_landing.gd", "scripts/anatomy_escape_repro.gd"]


def eligible(path):
    name = path.name
    is_asset_config = path.suffix == ".import" and "assets" in path.parts
    return (path.is_file() and (path.suffix.lower() != ".import" or is_asset_config)
            and path.suffix.lower() not in {".avi", ".zip", ".7z", ".blend"}
            and "source" not in path.parts and "__pycache__" not in path.parts
            and not name.startswith("c3-") and "baseline" not in name and ".pre-" not in name
            and name not in {"review-snapshot.json", "report-final-audit.md"})


paths = {p for p in FILES if (ROOT / p).is_file()}
paths.update(str((ROOT / p).with_suffix(".gd.uid").relative_to(ROOT))
             for p in FILES if p.endswith(".gd") and (ROOT / p).with_suffix(".gd.uid").is_file())
for prefix in PREFIXES:
    paths.update(str(p.relative_to(ROOT)) for p in (ROOT / prefix).rglob("*") if eligible(p))
# Keep specific upstream license texts without copying source archives.
paths.update(str(p.relative_to(ROOT)) for p in (ROOT / "assets").rglob("source/*")
             if p.is_file() and p.suffix in {".txt", ".md"})

with tempfile.TemporaryDirectory(prefix="dragon-review-index-") as directory:
    env = os.environ.copy()
    env["GIT_INDEX_FILE"] = str(Path(directory) / "index")

    def git(*args, **kwargs):
        return subprocess.check_output(["git", "-C", str(ROOT), *args], env=env, **kwargs).decode().strip()

    if git("rev-parse", "HEAD") != BASE:
        raise SystemExit("HEAD changed; resolve audit scope before creating snapshot")
    git("read-tree", BASE)
    git("add", "--pathspec-from-file=-", "--pathspec-file-nul",
        input=b"\0".join(p.encode() for p in sorted(paths)) + b"\0")
    tree = git("write-tree")
    head = git("commit-tree", tree, "-p", BASE,
               input=b"Local immutable Dragon v2 audit snapshot; no branch/index mutation\n")
    ref = "refs/codex-review/dragon-siege/final"
    git("update-ref", ref, head)
    result = {"base": BASE, "head": head, "tree": tree, "ref": ref,
              "range": BASE + ".." + head, "selected_files": sorted(paths),
              "excluded": "User PDF, unrelated diagnostics/screenshot imports, .godot binary cache, source archives, AVI, baseline recordings, pre-correction backups and audit output. Asset .import configuration is included.",
              "branch_and_user_index_unchanged": True}
    (ROOT / "docs/validation/v2/review-snapshot.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps({k: v for k, v in result.items() if k != "selected_files"}))

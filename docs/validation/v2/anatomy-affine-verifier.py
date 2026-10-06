"""Select original bind-space hull vertices for groups with bit-identical skin maps."""
import hashlib
import json
from pathlib import Path
import numpy as np
from scipy.spatial import ConvexHull, QhullError

DIRECTORY = Path(__file__).resolve().parent
result = {"method": "Exact coordinate deduplication within bit-identical skin groups; SciPy ConvexHull original indices; rank<3/<4 points retain all unique original coordinates",
          "tolerance_m": 1e-8, "sources": {}, "summaries": {}}
for source in sorted(DIRECTORY.glob("anatomy-affine-*.json")):
    if source.name in {"anatomy-affine-support-indices.json", "anatomy-affine-enclosure.json"}:
        continue
    data = json.loads(source.read_text())
    if "groups" not in data or not isinstance(data["groups"], list):
        continue
    groups = {}
    before = after = 0
    maximum = 0.0
    reduced = degenerate = 0
    for group in data["groups"]:
        points = np.asarray(group["full"], dtype=np.float64)
        unique, original_indices = np.unique(points, axis=0, return_index=True)
        indices = list(map(int, original_indices))
        before += len(points)
        if len(unique) >= 4 and np.linalg.matrix_rank(unique - unique[0], tol=1e-10) == 3:
            try:
                hull = ConvexHull(unique)
                candidate = [int(original_indices[i]) for i in hull.vertices]
                verify = ConvexHull(points[candidate])
                error = float(np.max(points @ verify.equations[:, :3].T + verify.equations[:, 3]))
                if error > 1e-8:
                    raise RuntimeError(f"{source.name}: group outside original hull by {error}m")
                indices = candidate
                maximum = max(maximum, error)
            except QhullError:
                degenerate += 1
        else:
            degenerate += 1
            if not all(tuple(p) in {tuple(q) for q in points[indices]} for p in points):
                raise RuntimeError("Degenerate group lost an original coordinate")
        if len(indices) < len(points):
            reduced += 1
        if not all(0 <= i < len(points) for i in indices):
            raise RuntimeError("Support is not an original index")
        groups[group["identity_hex"]] = indices
        after += len(indices)
    result["sources"][source.stem] = {"sha256": hashlib.sha256(source.read_bytes()).hexdigest(), "groups": groups}
    result["summaries"][source.stem] = {"original": before, "support": after, "groups": len(groups),
         "reduced_groups": reduced, "degenerate_fallback_groups": degenerate,
         "maximum_outside_m": maximum, "all_indices_original": True}
(DIRECTORY / "anatomy-affine-support-indices.json").write_text(json.dumps(result, indent=2) + "\n")
(DIRECTORY / "anatomy-affine-enclosure.json").write_text(json.dumps({"method": result["method"],
    "tolerance_m": result["tolerance_m"], "summaries": result["summaries"]}, indent=2) + "\n")
print(json.dumps(result["summaries"], indent=2))

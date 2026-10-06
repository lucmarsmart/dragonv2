"""Independent finite original-Skin versus actual concave fortress faces check.

Ray parity is accepted only for a closed triangle surface. Three unrelated ray
orientations must agree; open/ambiguous surfaces do not silently pass. Closest
triangle distance measures inside-vertex depth. This is a vertex check, not a
claim to enumerate every skin/fortress triangle intersection.
"""
import hashlib
import json
import sys
from pathlib import Path
import numpy as np

source = Path(sys.argv[1] if len(sys.argv) > 1 else 'docs/validation/v2/ground-escape-skin.json')
data = json.loads(source.read_text())

def parity(points, triangles, direction):
    direction = np.asarray(direction, float)
    direction /= np.linalg.norm(direction)
    a = triangles[:, 0]
    e1 = triangles[:, 1] - a
    e2 = triangles[:, 2] - a
    h = np.cross(direction, e2)
    determinant = np.einsum('ij,ij->i', e1, h)
    valid = np.abs(determinant) > 1e-12
    inverse = np.zeros_like(determinant)
    inverse[valid] = 1 / determinant[valid]
    answer = []
    for start in range(0, len(points), 64):
        s = points[start:start + 64, None, :] - a[None, :, :]
        u = np.einsum('bfj,fj->bf', s, h) * inverse
        q = np.cross(s, e1)
        v = np.einsum('bfj,j->bf', q, direction) * inverse
        t = np.einsum('bfj,fj->bf', q, e2) * inverse
        hits = valid & (u >= -1e-9) & (v >= -1e-9) & (u + v <= 1 + 1e-9) & (t > 1e-7)
        for row, selected in zip(t, hits):
            values = np.sort(row[selected])
            count = np.count_nonzero(np.diff(values) > 1e-7) + (len(values) > 0)
            answer.append(bool(count % 2))
    return np.asarray(answer, bool)

def depth(points, triangles):
    a, b, c = triangles[:, 0], triangles[:, 1], triangles[:, 2]
    ab, ac = b - a, c - a
    normal = np.cross(ab, ac)
    length = np.linalg.norm(normal, axis=1)
    good = length > 1e-12
    a, b, c, ab, ac, normal, length = [x[good] for x in (a, b, c, ab, ac, normal, length)]
    normal /= length[:, None]
    d00 = np.einsum('ij,ij->i', ab, ab)
    d01 = np.einsum('ij,ij->i', ab, ac)
    d11 = np.einsum('ij,ij->i', ac, ac)
    den = d00 * d11 - d01 * d01
    result = []
    for start in range(0, len(points), 64):
        p = points[start:start + 64, None, :]
        ap = p - a
        distance = np.einsum('bfj,fj->bf', ap, normal)
        projection = ap - distance[:, :, None] * normal
        d20 = np.einsum('bfj,fj->bf', projection, ab)
        d21 = np.einsum('bfj,fj->bf', projection, ac)
        u = (d11 * d20 - d01 * d21) / den
        v = (d00 * d21 - d01 * d20) / den
        inside = (u >= 0) & (v >= 0) & (u + v <= 1)
        best = np.where(inside, distance * distance, np.inf)
        for begin, end in ((a, b), (b, c), (c, a)):
            edge = end - begin
            relative = p - begin
            ratio = np.einsum('bfj,fj->bf', relative, edge) / np.einsum('fj,fj->f', edge, edge)
            residual = relative - np.clip(ratio, 0, 1)[:, :, None] * edge
            best = np.minimum(best, np.einsum('bfj,bfj->bf', residual, residual))
        result.extend(np.sqrt(np.min(best, axis=1)).tolist())
    return np.asarray(result)

cube_vertices=np.asarray([[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]],float)
cube_indices=np.asarray([[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[2,3,7],[2,7,6],[0,4,7],[0,7,3],[1,2,6],[1,6,5]])
cube=cube_vertices[cube_indices]
calibration_points=np.asarray([[0,0,0],[2,0,0],[.99,0,0]],float)
calibration_votes=[parity(calibration_points,cube,axis) for axis in ([1,.173,.071],[.219,1,.113],[.131,.317,1])]
calibration_depths=depth(calibration_points[[0,2]],cube)
negative_rejected=all(v.tolist()==[True,False,True] for v in calibration_votes) and abs(calibration_depths[0]-1)<1e-9 and abs(calibration_depths[1]-.01)<1e-9
assert negative_rejected,"Independent parity/distance calibration failed"

reports = {}
for wall, geometry in data['walls'].items():
    triangles = np.asarray(geometry['faces'], float).reshape(-1, 3, 3)
    _, ids = np.unique(np.round(triangles.reshape(-1, 3), 5), axis=0, return_inverse=True)
    ids = ids.reshape(-1, 3)
    edges = np.sort(np.concatenate((ids[:, [0, 1]], ids[:, [1, 2]], ids[:, [2, 0]])), axis=1)
    _, counts = np.unique(edges, axis=0, return_counts=True)
    closed = bool(np.all(counts == 2))
    poses = {}
    low, high = triangles.min(axis=(0, 1)), triangles.max(axis=(0, 1))
    for label, pose in data['poses'].items():
        vertices = np.asarray(pose['vertices'], float)
        candidates = vertices[np.all((vertices >= low - 1e-6) & (vertices <= high + 1e-6), axis=1)]
        votes = [parity(candidates, triangles, axis) for axis in ([1, .173, .071], [.219, 1, .113], [.131, .317, 1])]
        agreement = np.all(votes[0] == votes[1]) and np.all(votes[0] == votes[2])
        inside = candidates[votes[0]]
        depths = depth(inside, triangles) if len(inside) else np.asarray([])
        poses[label] = {'original_skin_vertices': len(vertices), 'vertices_in_wall_aabb': len(candidates),
                        'three_ray_orientations_agree': bool(agreement), 'inside_vertices': len(inside),
                        'maximum_inside_vertex_depth_m': float(depths.max()) if len(depths) else 0,
                        'passed': closed and bool(agreement) and len(vertices) == 25603 and (not len(depths) or depths.max() <= .05)}
    reports[wall] = {'triangles': len(triangles), 'closed_surface_at_10um_vertex_identity': closed,
                     'open_or_nonmanifold_edges': int(np.count_nonzero(counts != 2)), 'poses': poses}
result = {'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
          'scope': 'Original skin vertices versus actual exported concave module triangles; finite poses only.',
          'penetration_limit_m': .05, 'negative_inside_cube_rejected': bool(negative_rejected), 'walls': reports,
          'all_passed': bool(reports) and all(p['passed'] for r in reports.values() for p in r['poses'].values())}
out = source.with_name('ground-escape-skin-enclosure.json')
out.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
sys.exit(0 if result['all_passed'] else 1)

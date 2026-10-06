"""Verify every complete body-touching visual triangle against its assigned live hull.
Inputs are final Skin vertices, not joints or reconstructed hull corners.
"""
import argparse, hashlib, json, pathlib, sys
import numpy as np
from scipy.spatial import ConvexHull
p=argparse.ArgumentParser();p.add_argument('path');args=p.parse_args()
source=pathlib.Path(args.path);data=json.loads(source.read_text());triangles=data['triangles'];reports={}
by_hull={}
for tri in triangles:
    by_hull.setdefault(str(tri['hull']),set()).update(f"{tri['mesh']}:{tri['surface']}:{v}" for v in tri['indices'])
for label,pose in data['poses'].items():
    maximum=-np.inf; missing=0; outside=0
    for index,ids in by_hull.items():
        missing+=sum(key not in pose['vertices'] for key in ids)
        pts=np.array([pose['vertices'][key] for key in ids if key in pose['vertices']])
        eq=ConvexHull(np.array(pose['hulls'][index])).equations
        for start in range(0,len(pts),256):
            distances=np.max(pts[start:start+256]@eq[:,:3].T+eq[:,3],axis=1)
            maximum=max(maximum,float(distances.max()));outside+=int((distances>.001).sum())
    reports[label]={'original_vertices':len(pose['vertices']),'triangles':len(triangles),'maximum_outside_m':maximum,'missing_corners':missing,'outside_corners':outside,'passed':missing==0 and outside==0 and len(pose['vertices'])==25603}
first=next(iter(data['poses'].values()));index=next(iter(by_hull));eq=ConvexHull(np.array(first['hulls'][index])+np.array([20,0,0])).equations
pts=np.array([first['vertices'][key] for key in by_hull[index]])
negative_rejected=bool(np.any(np.max(pts@eq[:,:3].T+eq[:,3],axis=1)>.05))
summary={'body_touching_complete_triangles':len(triangles),'poses':len(reports),'coordinate_tolerance_m':.001,'maximum_outside_m':max(x['maximum_outside_m'] for x in reports.values()),'negative_translated_hull_rejected':negative_rejected,'all_passed':all(x['passed'] for x in reports.values()) and negative_rejected,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'checks':reports}
out=pathlib.Path('docs/validation/v2/anatomy-body-partition-enclosure.json');out.write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items()if k!='checks'}));sys.exit(0 if summary['all_passed'] else 1)

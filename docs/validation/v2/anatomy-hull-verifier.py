"""Select actual hull extrema, then independently verify every skinned membrane vertex.
Requires numpy/scipy. Fixture JSON is emitted by test_dragon_anatomy.gd; no bones-only proxy.
"""
import argparse,gzip,json,pathlib,sys
import numpy as np
from scipy.spatial import ConvexHull
parser=argparse.ArgumentParser()
parser.add_argument('paths',nargs='+')
parser.add_argument('--build',action='store_true')
parser.add_argument('--runtime-hulls',action='store_true')
args=parser.parse_args()
poses={}
for path in args.paths:
    opener=gzip.open if path.endswith('.gz') else open
    with opener(path,'rt') as handle: poses.update(json.load(handle))
partitions={pose.get('wing_partition','x-sign-historical') for pose in poses.values()}
if len(partitions)!=1:
    raise SystemExit('Cannot aggregate poses from different wing partitions: '+str(sorted(partitions)))
candidate_path=pathlib.Path('scripts/dragon_wing_extrema.json')
if args.build:
    candidates=set()
    for pose in poses.values():
        for cloud,ids in zip(pose['vertices'],pose['vertex_ids']):
            hull=ConvexHull(np.asarray(cloud))
            candidates.update(ids[int(i)] for i in hull.vertices)
    candidate_path.write_text(json.dumps(sorted(candidates),indent=1)+'\n')
else:
    candidates=set(json.loads(candidate_path.read_text()))
report={}
for label,pose in poses.items():
    outside=[]
    for side,(cloud,ids) in enumerate(zip(pose['vertices'],pose['vertex_ids'])):
        points=np.asarray(cloud)
        chosen=np.array([i for i,key in enumerate(ids) if key in candidates])
        hull=ConvexHull(np.asarray(pose['hulls'][side])) if args.runtime_hulls else ConvexHull(points[chosen])
        # Unit normals: signed distances are metres, including all vertices not just the chosen set.
        distance=-np.inf
        for start in range(0,len(points),256):
            distance=max(distance,float(np.max(points[start:start+256]@hull.equations[:,:3].T+hull.equations[:,3])))
        outside.append(distance)
    unique_count=len({key for ids in pose['vertex_ids'] for key in ids})
    report[label]={'max_signed_outside_m':outside,'all_vertices':unique_count,'point_entries_with_boundary_duplicates':sum(map(len,pose['vertices'])),'passed':max(outside)<=0.05 and unique_count==5412,'runtime_query_margin_m':pose.get('margin')}
summary={'candidate_count':len(candidates),'wing_partition':next(iter(partitions)),'poses':len(report),'all_passed':all(x['passed'] for x in report.values()),'maximum_outside_m':max(max(x['max_signed_outside_m'])for x in report.values()),'checks':report}
pathlib.Path('docs/validation/v2/anatomy-runtime-hull-enclosure.json' if args.runtime_hulls else 'docs/validation/v2/anatomy-hull-enclosure.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps({k:v for k,v in summary.items()if k!='checks'}))
sys.exit(0 if summary['all_passed'] else 1)

"""Check the actual collider against every triangle of the rendered closed egg.
Aligned regular64-gon rings make the radial source profile piecewise linear.
The outer profile is read from convex planes at all source/collider heights.
Its circumradius bounds every angle; source radius*cos(pi/64) bounds every
source angle from below. Their difference is linear between those heights.
"""
import hashlib,json,sys
from pathlib import Path
import numpy as np
from scipy.spatial import ConvexHull
base=Path(__file__).resolve().parent
source=Path(sys.argv[1]) if len(sys.argv)>1 else base/'anatomy-escape-egg-geometry.json'
data=json.loads(source.read_text())
points=np.unique(np.asarray(data['egg_faces_world']),axis=0)
collider=np.asarray(data.get('collider_points_world',points.tolist()))
hull=ConvexHull(collider)
planes=hull.equations
centre=np.array([300.,24.,82.])
source_y=np.unique(points[:,1])
radii=np.array([np.linalg.norm(points[points[:,1]==y][:,[0,2]]-centre[[0,2]],axis=1).max() for y in source_y])
heights=np.unique(np.r_[source_y,collider[:,1]])
maximum_gap=0.
for y in heights:
 if y<source_y.min()-1e-5 or y>source_y.max()+1e-5:continue
 denominator=planes[:,0]
 offset=planes[:,:3]@np.array([centre[0],y,centre[2]])+planes[:,3]
 positive=denominator>1e-8
 outer_radius=float(np.min(-offset[positive]/denominator[positive]))
 source_min_radius=float(np.interp(y,source_y,radii))*np.cos(np.pi/64)
 maximum_gap=max(maximum_gap,outer_radius-source_min_radius)
source_distances=np.max(points@planes[:,:3].T+planes[:,3],axis=1)
skin=np.asarray(data['skin_vertices_world'])
inside=np.max(skin@planes[:,:3].T+planes[:,3],axis=1)
report={'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'egg_triangles':len(data['egg_faces_world'])//3,'all_unique_source_vertices':len(points),'collider_input_points':len(collider),'convex_hull_vertices':len(hull.vertices),'maximum_original_vertex_outside_collider_m':float(max(0,source_distances.max())),'maximum_radial_expansion_bound_m':maximum_gap,'world_float_tolerance_m':.0001,'certified_surface_expansion_bound_m':maximum_gap+.0001,'allowed_surface_deviation_m':.05,'passed':bool(source_distances.max()<=.0001 and maximum_gap+.0001<=.05),'all_dragon_skin_vertices':len(skin),'skin_vertices_inside_convex_egg':int((inside<0).sum()),'skin_vertices_inside_over5cm':int((inside<-.05).sum()),'maximum_skin_inside_plane_depth_m':float(max(0,-inside.min())),'method':'All visual vertices certify every triangle inside convex collider; circumradius minus source inradius at union of all source/collider ring heights bounds expansion of the complete piecewise-linear radial surfaces; 0.1mm world-float allowance'}
(base/'anatomy-egg-hull-enclosure.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
sys.exit(0 if report['passed'] else 1)

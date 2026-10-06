"""Per-render costs from the same native Enter/T/L diagnostic before/after.
Does not substitute for the complete native mission's performance gate.
"""
import json,pathlib,hashlib
import numpy as np
base=pathlib.Path(__file__).parent
report={}
for tag in ['baseline','optimized']:
 path=base/f'anatomy-landing-profile-{tag}.json';data=json.loads(path.read_text());out={}
 for name,rows in [('landing',[r for r in data['rows']if r['state']==1]),('preparation_below12m',[r for r in data['rows']if r['state']==1 and r['proximity']<12]),('ground',[r for r in data['rows']if r['state']==2])]:
  dt=np.array([r['frame_ms']for r in rows]);tags=set(k for r in rows for k in r['costs']);costs={}
  for label in sorted(tags):
   samples=np.array([r['costs'].get(label,{}).get('total_us',0)/1000 for r in rows]);costs[label]={'mean_ms_per_render':float(samples.mean()),'p95_ms_per_render':float(np.percentile(samples,95)),'maximum_ms_per_render':float(samples.max())}
  out[name]={'frames':len(rows),'fps_native_wall':1000/float(dt.mean()),'p95_ms':float(np.percentile(dt,95)),'costs':costs}
 report[tag]={'source_data_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'display':data['display'],'device':data['device'],'ground_reached':data['ground_reached'],'states':out}
summary={'method':'Same1280x720native real scene warm360physics ticks, native Enter/T/L, no teleport/pose/state overrides; Time.get_ticks_usec between process_frame signals, profiling totals of preceding render; 30groundticks; no PNG/capture/ffmpeg during measurement. Instrumented diagnostic, not final mission acceptance.','runs':report}
(base/'anatomy-landing-profile-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
for tag,run in report.items():
 for state,v in run['states'].items():
  print(tag,state,'frames',v['frames'],'FPS',round(v['fps_native_wall'],2),'p95',round(v['p95_ms'],3),'wing_constrain_mean/p95',v['costs'].get('wing_constrain'),'ground_mean/p95',v['costs'].get('ground_total'))

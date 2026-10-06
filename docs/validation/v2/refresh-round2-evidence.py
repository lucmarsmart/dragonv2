"""Refresh current evidence metadata after frozen-source integration has passed."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
V = ROOT / 'docs/validation/v2'
def read(name): return json.loads((V / name).read_text())
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(name, data): (V / name).write_text(json.dumps(data, indent=2) + '\n')
launcher = read('launcher-final-run.json')
native = read('native-gates-run.json')
mission_receipt = read('playthrough-native-final-run.json')
movie_receipt = read('playthrough-metal-final-run.json')
bank_receipt=read('anatomy-bank-native-run.json')
feedback_receipt=read('user-feedback-native-run.json')
geometry_receipt=read('anatomy-enclosure-final-run.json')
visual_receipts=[read(name) for name in ['anatomy-flight-native-final-run.json','anatomy-flat-front-final-run.json','anatomy-real-front-final-run.json','anatomy-real-side-final-run.json']]
assert all(r['passed'] for r in [launcher, native, mission_receipt, movie_receipt, bank_receipt, feedback_receipt, geometry_receipt]+visual_receipts)
current_sources=launcher['source_files_sha256_after']
production_names={'project.godot','scenes/main.tscn','scripts/flight_camera.gd','scripts/hud.gd','scripts/terrain.gd','scripts/scenery_collisions.gd','scripts/siege_environment.gd','scripts/combat/siege_combat.gd','scripts/combat/siege_enemy.gd','scripts/combat/siege_projectile.gd','scripts/combat/siege_ui.gd','scripts/combat/play_siege_validation.gd'}
production_paths=[p for p in current_sources if p in production_names or p.startswith('scripts/') or p.startswith('shaders/') or (p.startswith('assets/') and p.endswith('.import'))]
assert all(movie_receipt['source_files_sha256_before'].get(p)==current_sources[p] for p in production_paths)
for receipt in [mission_receipt,bank_receipt,geometry_receipt] + feedback_receipt['runs'] + visual_receipts:
 assert all(receipt['source_files_sha256_before'].get(p)==current_sources[p] for p in production_paths)
for gate in native['gates']:
 assert all(gate['source_files_sha256'].get(p)==current_sources[p] for p in production_paths)
walk = read('anatomy-locomotion-contract.json')
camera = read('camera-surfaces.json')
ai = read('active-ai-los.json')
simultaneous=read('simultaneous-controls.json')
escape=read('ground-escape-trace.json')
descent=read('anatomy-descent-compact-candidate.json')
mouth=read('anatomy-mouth-report.json')
terrain_names=['terrain-player-escape-500-450.json','terrain-player-escape-850-130.json','terrain-player-escape--450-220.json']
terrain_reports={name:read(name) for name in terrain_names}
air=read('air-contact-escape.json')
player=read('player-aim-feedback.json')
retreat=player['measured_retreat']
assert player['checks']>=16 and player['attack_mode_pulses']==2
assert player['legacy_head_and_simultaneous_tests_modified'] is False
assert retreat['forbidden_key_frames']==0 and retreat['enemy_hp_after']<=0
assert retreat['mouse_overflow_body_yaw_deg']>10 and retreat['mouse_overflow_max_requested_head_yaw_deg']<=45 + 0.001 * 180 / 3.141592653589793
reference_paths=['docs/anatomy-reference.md','scripts/dragon_anatomy_reference.json','scripts/dragon_biomechanics.gd']
reference=json.loads((ROOT/'scripts/dragon_anatomy_reference.json').read_text())
assert reference['joint_count']==len(reference['joints'])==156 and reference['contains_muscle_simulation'] is False
assert sha(ROOT/reference['source'])==reference['source_sha256']
assert all(current_sources[path]==sha(ROOT/path) for path in reference_paths if path.startswith('scripts/'))
reference_record={'document':'docs/anatomy-reference.md','map':'scripts/dragon_anatomy_reference.json',
                  'runtime':'scripts/dragon_biomechanics.gd','joint_count':reference['joint_count'],
                  'source_glb_sha256':reference['source_sha256'],
                  'artifact_sha256':{path:sha(ROOT/path) for path in reference_paths},
                  'limits':'Original rig provenance and kinematic proxies; no simulated muscles, tissue volume, torque or biological certification. Offline mathematics is distinct from current physical/visual proof.'}
feedback_reports={'anatomy-mouth-report.json':mouth,'air-contact-escape.json':air,'player-aim-feedback.json':player,**terrain_reports}
assert not mouth['failures'] and mouth['sources_unchanged']
assert len(mouth['captures'])>=40
assert all(not report['failures'] and report['source_before']==report['source_after'] for report in terrain_reports.values())
assert air['pass'] and not air['failures'] and player['pass'] and not player['failures']
expected_feedback={'descent':3,'ground-escape':3,'mouth':40,'terrain-player-escape-500-450':3,'terrain-player-escape-850-130':3,'terrain-player-escape--450-220':3,'air-contact-escape':0,'player-aim-feedback':2}
assert {run['name'] for run in feedback_receipt['runs']}==set(expected_feedback)
for run in feedback_receipt['runs']:
 assert run['passed'] and run['report_passed'] and run['source_files_unchanged']
 assert len(run['captures_sha256'])>=expected_feedback[run['name']]
 assert run['report_sha256']==sha(V/run['report'])
 assert all(sha(V/name)==digest for name,digest in run['captures_sha256'].items())
mouth_run=next(run for run in feedback_receipt['runs'] if run['name']=='mouth')
assert all(Path(row['path']).name in mouth_run['captures_sha256'] for row in mouth['captures'])
player_run=next(run for run in feedback_receipt['runs'] if run['name']=='player-aim-feedback')
assert len(player['snapshots'])>=2 and all(Path(path).name in player_run['captures_sha256'] for path in player['snapshots'])
for name,report in feedback_reports.items():
 declared=report.get('source_sha256_before',report.get('source_before',report.get('sources_sha256',{})))
 assert declared, name
 for path,digest in declared.items():
  path=path.removeprefix('res://')
  assert sha(ROOT/path)==digest, (name,path)
  if path in current_sources: assert current_sources[path]==digest, (name,path)
ui = read('ui-measurements.json')
assert not walk['failures'] and not camera['failures'] and not ai['failures'] and ui['passed']
assert not simultaneous['failures'] and not escape['failures'] and not descent['failures']
clicks = [e for e in ui['measurements'] if e['state'] == 'start_click']
assert len(clicks) == 2 and all(e['first_frame_presented'] and e['combat_running'] and not e['overlay_visible'] and e['latency_ms'] < 100 for e in clicks)
benchmark = read('combat-performance.json')
mission = read('playthrough-native-report.json')
perf = mission['performance']['post_warmup_all_intervals']
print('Performance keys:', list(perf))
summary = {'generated_utc': datetime.now(timezone.utc).isoformat(), 'round': 2,
           'pre_review_validation_passed': True, 'review_pending': True,
           'launcher_receipt': 'launcher-final-run.json', 'native_receipt': 'native-gates-run.json',
           'mission_receipt': 'playthrough-native-final-run.json', 'movie_receipt': 'playthrough-metal-final-run.json',
           'per_foot': walk['stride']['feet'], 'bank': walk['bank']['sequences'],
           'camera_checks': camera['checks'], 'active_ai_checks': ai['checks'],
           'clicks': clicks, 'benchmark': benchmark, 'mission_performance': mission['performance'],
           'mission_health': mission['health'], 'mission_time_s': mission['time']}
summary['anatomy_reference']=reference_record
summary['user_feedback']={'native_receipt':'user-feedback-native-run.json',
                         'simultaneous_controls':'simultaneous-controls.json',
                         'ground_escape':'ground-escape-trace.json',
                         'descent':'anatomy-descent-compact-candidate.json',
                         'mouth':'anatomy-mouth-report.json','terrain':terrain_names,
                         'air_contact':'air-contact-escape.json','player_aim':'player-aim-feedback.json'}
summary['movie_reused_from_round1_with_unchanged_production_sources']=movie_receipt['started_utc'] < launcher['started_utc']
summary['movie_current_production_sources_sha256']={p:current_sources[p] for p in production_paths}
summary['movie_source_limit']='Production/mission sources and asset import settings must match current SHA. A reused prior movie is identified by its start timestamp; changed production requires a new recording.'
write('integration-round2.json', summary)
manifest = read('anatomy-manifest.json')
old = read('c3-round1-baseline-anatomy-manifest.json')['source_sha256']
current = launcher['source_files_sha256_after']
rig_paths = [p for p in old if p.startswith('scripts/dragon_')]
rig_unchanged=all(old[p] == current[p] for p in rig_paths)
manifest['generated_utc'] = summary['generated_utc']
manifest['final_runtime_frozen'] = True
manifest.pop('reopened_by_user_feedback',None)
manifest['source_sha256'] = current
selection=read('anatomy-hull-enclosure.json')
runtime_hulls=read('anatomy-runtime-hull-enclosure.json')
body=read('anatomy-body-partition-enclosure.json')
assert selection['all_passed'] and runtime_hulls['all_passed'] and body['all_passed']
assert selection['wing_partition']==runtime_hulls['wing_partition']=='rig-root96-120-boundary-v1'
manifest['enclosure_method']=read('anatomy-enclosure-method.json')
manifest['enclosure_method']['current_combined_verification_receipt']='anatomy-enclosure-final-run.json'
manifest['enclosure_method']['current_pose_inputs']=geometry_receipt['pose_inputs']
manifest['enclosure_method']['selection_verification']={'poses':selection['poses'],'maximum_outside_m':selection['maximum_outside_m'],'sha256':sha(V/'anatomy-hull-enclosure.json')}
manifest['enclosure_method']['runtime_verification']={'poses':runtime_hulls['poses'],'maximum_outside_m':runtime_hulls['maximum_outside_m'],'sha256':sha(V/'anatomy-runtime-hull-enclosure.json')}
metrics=manifest['metrics']
metrics['anatomy_reference']=reference_record
metrics['oral_emitter']={'report':'anatomy-mouth-report.json','checks':mouth['checks'],'asset_landmarks':mouth['asset_landmarks'],
                       'maximum_oral_error_m':max(row['maximum_oral_error_m'] for row in mouth['cases']),
                       'native_capture_count':len(next(run for run in feedback_receipt['runs'] if run['name']=='mouth')['captures_sha256'])}
metrics['terrain_player_escape']={name:{key:report[key] for key in ['fixture_xz','landing_ticks','stages','stage_quality','minimum_skin_terrain_clearance_m','maximum_stance_slide_m','maximum_overlap_count','maximum_prop_overlap_count','original_vertices_checked']} for name,report in terrain_reports.items()}
metrics['air_contact_escape']={key:air[key] for key in ['checks','climb_height_m','maximum_actual_overlaps','scope']}
metrics['player_aim_feedback']={'report':'player-aim-feedback.json','checks':player['checks'],'measured_retreat':player['measured_retreat'],'limits':player['limits'],
                              'attack_mode_pulses':player['attack_mode_pulses'],'input_method':player['measured_input_method'],
                              'camera_view':'above front of head; FLYING when attack mode active',
                              'legacy_head_and_simultaneous_tests_modified':player['legacy_head_and_simultaneous_tests_modified']}
metrics.update({'final_geometry_candidates':selection['candidate_count'],'runtime_hull_poses':runtime_hulls['poses'],
                'runtime_hull_maximum_outside_m':runtime_hulls['maximum_outside_m'],'selection_verified_poses':selection['poses'],
                'independent_holdout_poses':sum(row['poses'] for row in geometry_receipt['pose_inputs'] if 'holdout' in row['file']),
                'construction_extension_poses':sum(row['poses'] for row in geometry_receipt['pose_inputs'] if 'holdout' not in row['file']),
                'body_touching_complete_triangles':body['body_touching_complete_triangles'],'body_triangle_proof_poses':body['poses'],
                'body_triangle_maximum_outside_m':body['maximum_outside_m'],'wing_partition':runtime_hulls['wing_partition'],
                'human_ground_escape':{k:escape[k] for k in ['stages','minimum_skin_terrain_clearance_m','maximum_stance_slide_m','maximum_wing_step_deg','maximum_head_step_deg','retreat_fire_frames']},
                'human_descent_report':'anatomy-descent-compact-candidate.json'})
windows=[]
for line in (V/'launcher-final.log').read_text().splitlines():
 if line.startswith('CONTINUOUS_BODY_TERRAIN '):
  label,raw=line[len('CONTINUOUS_BODY_TERRAIN '):].split(' ',1)
  row=json.loads(raw);row['label']=label;windows.append(row)
assert len(windows)==6 and all(row['missing_checks']==0 and row['penetrating']==0 and row['wing_penetrating']==0 for row in windows)
metrics.update({'continuous_windows':len(windows),'continuous_frames':sum(row['frames'] for row in windows),
                'body_observed_surface_queries':sum(row['observed_surface_vertices'] for row in windows),
                'continuous_penetrations':sum(row['penetrating'] for row in windows),'continuous_wing_penetrations':sum(row['wing_penetrating'] for row in windows),
                'continuous_missing_body_checks':sum(row['missing_checks'] for row in windows),
                'continuous_minimum_body_clearance_m':min(row['minimum_m'] for row in windows),
                'continuous_maximum_head_step_deg':max(row['head_step_deg'] for row in windows),
                'continuous_maximum_stance_slide_m':max(row['stance_slide_m'] for row in windows),'continuous_windows_details':windows})
manifest['current_geometry_limits']='Finite poses of stable rig-root wing partition; historical X-sign poses remain historical and are not aggregated as current proof.'
manifest['native_anatomy_capture_source_limit']='Current lateral, frontal, flight, bank and human-regression captures have fresh native receipts matching the frozen production SHA. Camera/evidence adapters are declared separately; MovieMaker never measures FPS.'
manifest['escape_regression_status']=f"Current native mission won via actual Input, health{mission['health']}/240, time{mission['time']}s; all phase/locomotion groups meet>=60FPS/p95<=25ms. Historical reds remain preserved."
manifest['landing_profile']['status']='Historical diagnostic measurements before the human-feedback correction. Not current performance acceptance; current native performance receipts govern.'
manifest['frontal_visual_evidence']['current_sources_verified']=True
manifest['human_descent_metrics']={k:descent[k] for k in ['maximum_joint_step_deg','maximum_world_joint_step_deg','ordinary_first_walk_joint_step_deg','ordinary_first_walk_axis_step_deg','maximum_translation_change','minimum_ground_claw_clearance_m','maximum_stance_slip_m','maximum_walk_target_step_m','maximum_length_error_m']}

manifest['scope_limits']=[
 f"Finite{runtime_hulls['poses']}current stable-partition poses of all5412 original wing vertices; independent holdouts are declared separately. No universal deformation guarantee.",
 f"Continuous20,191body/neck/allclaw+5412wing vertices across{metrics['continuous_frames']}frames in concrete terrain windows; point/ray sampling does not claim universal continuous triangle collision.",
 'Ground corridor final Skin also allows the unchanged5cm penetration budget; actual maximum intrusion is declared in human_ground_escape.',
 'Ground slide/snap may differ from cast; tests observe final published Skin.',
 'Native mission FPS measured without MovieMaker or readback; fixed60Hz captures demonstrate finite visual cases.',
 'Three real terrain fixtures and one physical aerial contact fixture retain all18 hulls; coverage is finite and does not certify every slope or obstacle.',
 'Oral skin midpoint is independently measured; front/side captures require visual review. Above-head camera viewport and physical LOS alone do not certify rendered Skin/wing occlusion.',
 'Human encounter observation uses W/S, unclamped mouse and left click with one released T pulse per mode transition; legacy independent-head and simultaneous-control suites are unchanged.',
 reference_record['limits']
]
manifest['source_fingerprint_sha256'] = hashlib.sha256(json.dumps(current, sort_keys=True).encode()).hexdigest()
imports = {str(p.relative_to(ROOT)): sha(p) for p in sorted((ROOT / 'assets').rglob('*.import')) if 'source' not in p.parts}
manifest['imports_count'] = len(imports)
manifest['imports_sha256'] = imports
manifest['imports_fingerprint_sha256'] = hashlib.sha256(json.dumps(imports, sort_keys=True).encode()).hexdigest()
manifest['fingerprint_method'] = 'SHA256 of JSON mapping sorted by key; imports cover asset .import settings, not generated binary cache.'
manifest['c3_round2_coverage'] = {'report': 'integration-round2.json', 'rig_sources_unchanged_since_round1': rig_unchanged, 'rig_paths': rig_paths,
                                'per_foot_cycles': {k: len(f['events']) for k, f in walk['stride']['feet'].items()},
                                'camera_checks': camera['checks'], 'active_ai_checks': ai['checks'], 'clicks': clicks,
                                'bank': walk['bank']['sequences']}
for path in list(manifest['source_and_artifact_sha256']):
 p = ROOT / path
 if p.is_file(): manifest['source_and_artifact_sha256'][path] = sha(p)
for name in ['anatomy-locomotion-contract.json', 'anatomy-locomotion-contract-native.json','anatomy-bank-native-run.json','camera-surfaces.json', 'active-ai-los.json', 'integration-round2.json', 'launcher-final-run.json', 'native-gates-run.json', 'ui-measurements.json', 'playthrough-native-final-run.json', 'playthrough-metal-final-run.json','user-feedback-native-run.json','ground-escape-trace.json','anatomy-descent-compact-candidate.json','anatomy-enclosure-final-run.json','anatomy-stable-current-all-poses.json.gz']+list(feedback_reports):
 manifest['source_and_artifact_sha256']['docs/validation/v2/' + name] = sha(V / name)
manifest['source_and_artifact_sha256'].update(reference_record['artifact_sha256'])
for run in feedback_receipt['runs']:
 for name,digest in run['captures_sha256'].items():
  manifest['source_and_artifact_sha256']['docs/validation/v2/'+name]=digest
manifest['performance_gate'] = {'native_benchmark': {'fps': benchmark['fps_average'], 'p95_ms': benchmark['frame_p95_ms'], 'receipt': 'native-gates-run.json'},
                                'native_mission': {'fps':perf['fps_actual_wall'],'p95_ms':perf['frame_p95_ms'],'measurement': perf, 'all_groups_passed': mission_receipt['performance_passed'], 'receipt': 'playthrough-native-final-run.json'}}
write('anatomy-manifest.json', manifest)
print('Current evidence metadata refreshed; both independent reviews remain pending.')

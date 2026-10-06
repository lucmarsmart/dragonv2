extends SceneTree
var scene: Node3D
var failures: Array[String]=[]
var measurements: Array[Dictionary]=[]
func _initialize(): call_deferred("run")
func ticks(n: int):
 for _i in n:
  await physics_frame
  await process_frame
func key(code: Key):
 var e=InputEventKey.new()
 e.keycode=code
 e.physical_keycode=code
 e.pressed=true
 Input.parse_input_event(e)
 e=InputEventKey.new()
 e.keycode=code
 e.physical_keycode=code
 Input.parse_input_event(e)
func click(button: Button):
 print("UI_CLICK ",button.text," pos=",button.get_global_rect()," mouse_mode=",Input.get_mouse_mode())
 var p=button.get_global_transform_with_canvas()*(button.size*0.5)
 var motion:=InputEventMouseMotion.new()
 motion.position=p
 motion.global_position=p
 root.push_input(motion,true)
 if DisplayServer.get_name()!="headless": Input.warp_mouse(p)
 await ticks(2)
 for pressed in [true,false]:
  var e=InputEventMouseButton.new()
  e.position=p
  e.global_position=p
  e.button_index=MOUSE_BUTTON_LEFT
  e.pressed=pressed
  root.push_input(e,true)
  await ticks(3)
func click_to_present(button: Button, combat: Node, ui: Node):
 # Hover preparation is outside the interval. Measure the actual press/release
 # pair through the first rendered frame, not a keyboard shortcut or handler call.
 var p=button.get_global_transform_with_canvas()*(button.size*0.5)
 var motion:=InputEventMouseMotion.new()
 motion.position=p
 motion.global_position=p
 root.push_input(motion,true)
 if DisplayServer.get_name()!="headless": Input.warp_mouse(p)
 await ticks(2)
 var started=Time.get_ticks_usec()
 for pressed in [true,false]:
  var event:=InputEventMouseButton.new()
  event.position=p
  event.global_position=p
  event.button_index=MOUSE_BUTTON_LEFT
  event.pressed=pressed
  root.push_input(event,true)
 var dispatch_latency=float(Time.get_ticks_usec()-started)/1000.0
 await process_frame
 var presented=DisplayServer.get_name()!="headless"
 if presented: await RenderingServer.frame_post_draw
 var latency=float(Time.get_ticks_usec()-started)/1000.0
 measurements.append({"state":"start_click","viewport":str(root.size),"latency_ms":latency,"dispatch_latency_ms":dispatch_latency,"first_frame_presented":presented,"combat_running":combat.is_running(),"overlay_visible":ui.overlay.visible,"input_method":"Viewport.push_input: actual left-button press/release","threshold_ms":100})
 if not combat.is_running() or ui.overlay.visible or latency>100:
  failures.append("Actual click latency/running/overlay "+str([latency,combat.is_running(),ui.overlay.visible]))
func snap(state: String):
 await ticks(8)
 if DisplayServer.get_name()!="headless":
  root.get_texture().get_image().save_png("res://docs/validation/v2/ui-"+state+"-"+str(root.size.x)+".png")
 var ui=scene.get_node("SiegeUI")
 var rect: Rect2=ui.panel.get_global_rect()
 var bounded: bool=Rect2(Vector2.ZERO,Vector2(root.size)).encloses(rect)
 if ui.overlay.visible and not bounded: failures.append(state+" popup outside "+str(root.size))
 var visible_buttons=0
 var small=0
 var outside=0
 for button in all_buttons(scene):
  if not button.is_visible_in_tree(): continue
  visible_buttons+=1
  if button.size.x<44 or button.size.y<44: small+=1
  if not Rect2(Vector2.ZERO,Vector2(root.size)).encloses(button.get_global_rect()): outside+=1
 if small>0 or outside>0: failures.append(state+" buttons small/outside "+str([small,outside]))
 measurements.append({"state":state,"viewport":str(root.size),"panel":str(rect),"popup_bounded":bounded,"buttons_visible":visible_buttons,"buttons_small":small,"buttons_outside":outside})
func all_buttons(node: Node) -> Array[Button]:
 var result: Array[Button]=[]
 if node is Button: result.append(node)
 for child in node.get_children(): result.append_array(all_buttons(child))
 return result
func inspect_native_ui(state: String):
 var visible: Array[Button]=[]
 for b in all_buttons(scene):
  if b.is_visible_in_tree() and not b.disabled: visible.append(b)
 if visible.is_empty(): return
 visible[0].grab_focus()
 var visited: Array[Button]=[]
 for _i in visible.size()+1:
  var focus=root.gui_get_focus_owner()
  if focus is Button and focus in visible and focus not in visited: visited.append(focus)
  key(KEY_TAB)
  await process_frame
 if visited.size()!=visible.size(): failures.append(state+" keyboard focus misses visible buttons")
 var fonts: Dictionary={}
 var sizes: Dictionary={}
 var colors: Dictionary={}
 collect_style(scene,fonts,sizes,colors)
 measurements.append({"state":state,"viewport":str(root.size),"keyboard_focus_reached":visited.size(),"keyboard_focus_expected":visible.size(),"font_families":fonts.keys(),"font_sizes":sizes.keys(),"ui_colors":colors.keys()})
 if fonts.size()>2 or sizes.size()>8 or colors.size()>20: failures.append(state+" style inventory exceeds DV10")
func collect_style(node: Node,fonts: Dictionary,sizes: Dictionary,colors: Dictionary):
 if (node is Label or node is Button) and node.is_visible_in_tree():
  fonts[node.get_theme_font("font").get_font_name()]=true
  sizes[node.get_theme_font_size("font_size")]=true
  var font_color_name="font_disabled_color" if node is Button and node.disabled else "font_color"
  colors[(node.get_theme_color(font_color_name)*node.modulate).to_html()]=true
  if node is Label:
   for name in ["font_outline_color","font_shadow_color"]:
    var color=node.get_theme_color(name)
    if color.a>0.01: colors[color.to_html()]=true
 if node is Control and node.is_visible_in_tree():
  var styles: Array[String]=[]
  if node is Button: styles=["disabled" if node.disabled else "normal"]
  elif node is PanelContainer: styles=["panel"]
  elif node is ProgressBar: styles=["background","fill"]
  for name in styles:
   var style=node.get_theme_stylebox(name)
   if style is StyleBoxFlat:
    if style.bg_color.a>0.01: colors[style.bg_color.to_html()]=true
    if style.border_color.a>0.01: colors[style.border_color.to_html()]=true
  if node is ColorRect and node.color.a>0.01: colors[node.color.to_html()]=true
 for child in node.get_children(): collect_style(child,fonts,sizes,colors)
func run():
 root.size=Vector2i(1280,720)
 scene=load("res://scenes/main.tscn").instantiate()
 root.add_child(scene)
 await ticks(180)
 var ui=scene.get_node("SiegeUI")
 var combat=scene.get_node("SiegeCombat")
 ui.secondary.button_down.connect(func(): print("UI_SECONDARY_DOWN"))
 ui.secondary.button_up.connect(func(): print("UI_SECONDARY_UP"))
 ui.secondary.pressed.connect(func(): print("UI_SECONDARY_PRESSED visible=",ui.credits_visible))
 for size in [Vector2i(1280,720),Vector2i(960,540)]:
  root.size=size
  await ticks(8)
  await snap("briefing")
  await inspect_native_ui("briefing")
  ui.secondary.grab_focus()
  key(KEY_ENTER)
  await ticks(4)
  if not ui.credits_visible or combat.is_running(): failures.append("Enter did not activate focused credits button")
  key(KEY_ENTER)
  await ticks(4)
  if ui.credits_visible: failures.append("Focused credits button did not close credits")
  await click(ui.secondary)
  await snap("credits")
  await inspect_native_ui("credits")
  if not ui.credits_visible: failures.append("Actual credits click failed")
  await click(ui.secondary)
  for _i in 3:
   if root.gui_get_focus_owner()==ui.action: break
   key(KEY_TAB)
   await process_frame
  var started=Time.get_ticks_usec()
  key(KEY_ENTER)
  var dispatch_latency=float(Time.get_ticks_usec()-started)/1000.0
  await process_frame
  if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
  var latency=float(Time.get_ticks_usec()-started)/1000.0
  measurements.append({"state":"start_keyboard","viewport":str(root.size),"latency_ms":latency,"dispatch_latency_ms":dispatch_latency,"input_method":"KEY_ENTER"})
  if not combat.is_running() or latency>100: failures.append("Start latency/running "+str(latency))
  await snap("active")
  await inspect_native_ui("active")
  key(KEY_T)
  await snap("aim")
  key(KEY_H)
  await snap("help")
  key(KEY_H)
  key(KEY_P)
  await process_frame
  # Paused SceneTree cannot advance physics; captures use process frames.
  for _i in 8: await process_frame
  if DisplayServer.get_name()!="headless":
   root.get_texture().get_image().save_png("res://docs/validation/v2/ui-pause-"+str(size.x)+".png")
  key(KEY_P)
  await process_frame
  # UI state fixtures do not stand in for combat's live defeat/victory tests.
  combat.phase=combat.Phase.DEFEAT
  combat._hold_player(true)
  combat.state_changed.emit()
  await snap("defeat")
  await click(ui.action)
  await ticks(8)
  if combat.phase!=combat.Phase.BRIEFING:
   failures.append("Actual retry did not restore briefing before click timing")
  await click_to_present(ui.action,combat,ui)
  combat.phase=combat.Phase.VICTORY
  combat.state_changed.emit()
  await snap("victory")
  await click(ui.action)
 var report={"measurements":measurements,"failures":failures,"passed":failures.is_empty(),"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"scope":"UI state/input gate; win/lose presentation fixtures, not mission acceptance"}
 var filename="ui-measurements-headless.json" if DisplayServer.get_name()=="headless" else "ui-measurements.json"
 var f=FileAccess.open("res://docs/validation/v2/"+filename,FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
 print("UI_GATE ",JSON.stringify(report))
 scene.queue_free()
 await ticks(30)
 quit(0 if failures.is_empty() else 1)

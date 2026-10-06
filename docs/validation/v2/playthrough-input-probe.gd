extends SceneTree
func _initialize():
 call_deferred("run")
func press(code,down):
 var event:=InputEventKey.new()
 event.keycode=code
 event.physical_keycode=code
 event.pressed=down
 Input.parse_input_event(event)
func run():
 press(KEY_W,true)
 await process_frame
 await process_frame
 print("INPUTPROBE W=",Input.is_key_pressed(KEY_W)," shift=",Input.is_key_pressed(KEY_SHIFT))
 press(KEY_SHIFT,true)
 await process_frame
 await process_frame
 print("INPUTPROBE W+Shift W=",Input.is_key_pressed(KEY_W)," shift=",Input.is_key_pressed(KEY_SHIFT))
 press(KEY_SHIFT,false)
 await process_frame
 await process_frame
 print("INPUTPROBE WafterShift W=",Input.is_key_pressed(KEY_W)," shift=",Input.is_key_pressed(KEY_SHIFT))
 quit()

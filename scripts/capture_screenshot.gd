extends Node

var frames = 0

func _ready():
	print("Capturador de pantalla iniciado...")

func _process(_delta):
	frames += 1
	if frames == 25:
		var img = get_viewport().get_texture().get_image()
		if img:
			var path = "c:/Proyectos/Dragon v2/real_camera_screenshot.png"
			img.save_png(path)
			print("Captura REAL guardada exitosamente en: ", path)
		else:
			print("Error: la imagen del viewport es null.")
		get_tree().quit(0)

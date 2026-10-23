extends RefCounted
class_name WindCurrentSimulator

## SIMULADOR DE CORRIENTES DE VIENTO Y TURBULENCIA OROGRÁFICA
## Modela el flujo atmosférico realista sobre el terreno:
## - Viento predominante de montaña con deriva angular.
## - Aceleración por encajonamiento en el cañón del río y valles.
## - Ráfagas no-periódicas multicapa y micro-turbulencias orgánicas.

var base_wind_direction := Vector2(0.7071, -0.7071).normalized() # Dirección dominante (Noroeste a Sureste)
var base_wind_speed := 4.2 # m/s (Brisa moderada de montaña)
var gust_strength := 3.6   # Fuerza pico de ráfagas
var gust_frequency := 0.28 # Hz de ráfaga
var turbulence_noise: FastNoiseLite

func _init() -> void:
	turbulence_noise = FastNoiseLite.new()
	turbulence_noise.seed = 492026
	turbulence_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	turbulence_noise.frequency = 0.008
	turbulence_noise.fractal_octaves = 3

## Devuelve el vector 3D de viento en cualquier coordenada del mundo y tiempo actual
func get_wind_at(pos: Vector3, time: float) -> Vector3:
	# 1. Ráfagas globales con modulación no-lineal
	var gust_t := time * gust_frequency
	var gust_mod := pow(maxf(sin(gust_t * 1.0) * 0.5 + sin(gust_t * 2.3 + 1.2) * 0.35 + sin(gust_t * 5.1 + 2.7) * 0.15, 0.0), 1.5)
	var current_speed := base_wind_speed + gust_mod * gust_strength
	
	# 2. Desviación orográfica por relieve
	var local_noise := turbulence_noise.get_noise_2d(pos.x, pos.z)
	var angle_deflection := local_noise * 0.42 # Hasta ~24 grados de desvío por crestas y árboles
	
	var dir_x := base_wind_direction.x * cos(angle_deflection) - base_wind_direction.y * sin(angle_deflection)
	var dir_z := base_wind_direction.x * sin(angle_deflection) + base_wind_direction.y * cos(angle_deflection)
	
	# 3. Encajonamiento en el río (el viento sigue el cauce fluvial)
	var river_center_x := sin(pos.z * 0.0041) * 62.0 + sin(pos.z * 0.0103 + 0.6) * 18.0
	var dist_river := absf(pos.x - river_center_x)
	if dist_river < 45.0:
		var canyon_factor := (1.0 - dist_river / 45.0) * 0.35
		current_speed *= (1.0 + canyon_factor)
	
	# 4. Amortiguación vertical (en la superficie el viento es frenado por la capa límite)
	var ground_boundary := clampf(pos.y / 15.0, 0.55, 1.4)
	var final_speed := current_speed * ground_boundary
	
	return Vector3(dir_x, 0.0, dir_z).normalized() * final_speed

## Devuelve la intensidad escalar [0.0, 1.0] para alimentar shaders de árboles y pasto
func get_shader_wind_strength(pos: Vector3, time: float) -> float:
	var w := get_wind_at(pos, time)
	return clampf(w.length() / (base_wind_speed + gust_strength), 0.15, 1.0)

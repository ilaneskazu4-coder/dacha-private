class_name DayNight
extends Node
## Цикл дня и ночи: день 150 с, закат 20 с, ночь 85 с, рассвет 15 с.

signal night_started(day: int)
signal dawn_started(day: int)
signal day_started(day: int)

const T := 270.0
const DAY_END := 150.0
const DUSK_END := 170.0
const NIGHT_END := 255.0

var t := 18.0
var day := 1
var is_night := false
var darkness := 0.0
var sun: DirectionalLight3D
var env: Environment
var sky: ProceduralSkyMaterial


func setup(s: DirectionalLight3D, e: Environment, k: ProceduralSkyMaterial) -> void:
	sun = s
	env = e
	sky = k
	is_night = t >= DUSK_END and t < NIGHT_END
	_apply()


func advance(delta: float) -> void:
	var prev := t
	t += delta
	if prev < DUSK_END and t >= DUSK_END:
		is_night = true
		night_started.emit(day)
	if prev < NIGHT_END and t >= NIGHT_END:
		is_night = false
		dawn_started.emit(day)
	if t >= T:
		t -= T
		day += 1
		day_started.emit(day)
	_apply()


## Подтянуть время к времени хозяина комнаты (игра вместе).
func sync_to(nt: float, nday: int) -> void:
	if absf(nt - t) < 1.2 and nday == day:
		t = lerpf(t, nt, 0.5)
	else:
		t = nt
		day = nday
		is_night = t >= DUSK_END and t < NIGHT_END
	_apply()


func seconds_to_change() -> float:
	if t < DUSK_END:
		return DUSK_END - t
	if t < NIGHT_END:
		return NIGHT_END - t
	return T - t


func cycle_frac() -> float:
	return t / T


func _smooth(a: float, b: float, x: float) -> float:
	return smoothstep(0.0, 1.0, clampf((x - a) / (b - a), 0.0, 1.0))


func _apply() -> void:
	if t < 140.0:
		darkness = 0.0
	elif t < DUSK_END:
		darkness = _smooth(140.0, DUSK_END, t)
	elif t < NIGHT_END:
		darkness = 1.0
	else:
		darkness = 1.0 - _smooth(NIGHT_END, T, t)
	var dusk := sin(darkness * PI)
	# солнце / луна
	var s := clampf(t / DAY_END, 0.0, 1.0)
	var elev := lerpf(10.0, 72.0, sin(s * PI))
	var day_col := Color("fff1d8").lerp(Color("ff9a55"), dusk * 0.8)
	var day_e := clampf(0.35 + sin(s * PI) * 0.6, 0.35, 0.95)
	sun.rotation_degrees = Vector3(-lerpf(elev, 38.0, darkness), lerpf(-70.0, 80.0, s) if darkness < 0.5 else 200.0, 0.0)
	sun.light_color = day_col.lerp(Color("7a9aff"), darkness)
	sun.light_energy = lerpf(day_e, 0.28, darkness)
	# окружение
	env.ambient_light_color = Color("b4c8e8").lerp(Color("3a4a9a"), darkness)
	env.ambient_light_energy = lerpf(0.55, 0.62, darkness)
	env.fog_light_color = Color("c4dcf0").lerp(Color("14182e"), darkness).lerp(Color("e0a070"), dusk * 0.5)
	env.fog_density = lerpf(0.0035, 0.011, darkness)
	sky.sky_top_color = Color("3f7fd8").lerp(Color("060a1c"), darkness)
	sky.sky_horizon_color = Color("b4d4ee").lerp(Color("141a38"), darkness).lerp(Color("ff9a55"), dusk * 0.7)
	sky.ground_horizon_color = sky.sky_horizon_color
	sky.ground_bottom_color = Color("6a8a5a").lerp(Color("0a0e18"), darkness)

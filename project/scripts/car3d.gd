class_name Car3D
extends CharacterBody3D
## Volkswagen Passat B3 универсал. Едет вперёд по -Z. Стик: вверх — газ, вниз — тормоз/назад, вбок — руль.

const MAX_FWD := 21.0
const MAX_REV := 7.0
const ACC := 12.0

var kind := "passat"      # passat, uaz, sport, police
var max_fwd := MAX_FWD
var acc := ACC
var body_col := Color("3f7a62")
var ai := false
var siren_t := 0.0
var siren_a: MeshInstance3D
var siren_b: MeshInstance3D
var siren_light: OmniLight3D
var fixed := false
var occupied := false
var speed := 0.0
var logs_on_roof := 0
var shown_logs := -1
var wheel_spin := 0.0
var steer_vis := 0.0
var shake_t := 0.0
var wheels_front: Array = []
var wheels_all: Array = []
var roof_logs: Node3D
var smoke: CPUParticles3D
var tail_glow: MeshInstance3D
var spots: Array = []
var door: Node3D
var door_open := 0.0:
	set(v):
		door_open = v
		if door != null:
			door.rotation.y = -v * 1.15


func _ready() -> void:
	match kind:
		"sport":
			max_fwd = 33.0
			acc = 19.0
			body_col = Color("f2c418")
		"uaz":
			max_fwd = 15.0
			acc = 9.0
			body_col = Color("6e7a3c")
		"police":
			max_fwd = 25.0
			acc = 15.0
			body_col = Color("e9edf2")
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.9, 1.3, 4.7)
	cs.shape = sh
	cs.position.y = 0.72
	add_child(cs)
	_build()


func _build() -> void:
	var body_c := body_col
	var dark := Color("1d2a30")
	var trim := Color("15151a")
	var parts: Array = []
	# кузов: низ, капот, багажник-универсал
	parts.append(MeshKit.box(Vector3(1.78, 0.62, 4.6), Vector3(0, 0.62, 0), body_c))
	parts.append(MeshKit.box(Vector3(1.7, 0.16, 1.15), Vector3(0, 0.98, -1.6), body_c.lightened(0.05)))
	# салон (длинная крыша универсала)
	parts.append(MeshKit.box(Vector3(1.62, 0.48, 2.9), Vector3(0, 1.13, 0.42), body_c.lightened(0.1)))
	parts.append(MeshKit.box(Vector3(1.62, 0.06, 2.9), Vector3(0, 1.39, 0.42), body_c.lightened(0.2)))
	# стёкла
	parts.append(MeshKit.box(Vector3(1.5, 0.5, 0.06), Vector3(0, 1.15, -0.95), dark, Vector3(-0.72, 0, 0)))
	parts.append(MeshKit.box(Vector3(1.64, 0.28, 2.3), Vector3(0, 1.18, 0.4), dark))
	parts.append(MeshKit.box(Vector3(1.5, 0.34, 0.06), Vector3(0, 1.18, 1.9), dark, Vector3(0.12, 0, 0)))
	# стойки между стёклами
	for z in [-0.35, 0.55]:
		parts.append(MeshKit.box(Vector3(1.66, 0.3, 0.1), Vector3(0, 1.18, z), body_c.lightened(0.1)))
	# бамперы
	parts.append(MeshKit.box(Vector3(1.84, 0.24, 0.2), Vector3(0, 0.42, -2.35), trim))
	parts.append(MeshKit.box(Vector3(1.84, 0.24, 0.2), Vector3(0, 0.42, 2.35), trim))
	# решётка и номер
	parts.append(MeshKit.box(Vector3(0.8, 0.14, 0.04), Vector3(0, 0.68, -2.31), Color("2a2a30")))
	parts.append(MeshKit.box(Vector3(0.5, 0.12, 0.03), Vector3(0, 0.45, -2.46), Color("f2f2f2")))
	parts.append(MeshKit.box(Vector3(0.5, 0.12, 0.03), Vector3(0, 0.45, 2.46), Color("f2f2f2")))
	# рейлинги на крыше
	for x in [-0.65, 0.65]:
		parts.append(MeshKit.box(Vector3(0.05, 0.05, 2.6), Vector3(x, 1.45, 0.42), Color("c9ced6")))
	# зеркала и ручки
	for x in [-0.95, 0.95]:
		parts.append(MeshKit.box(Vector3(0.12, 0.12, 0.2), Vector3(x, 1.04, -0.95), trim))
	# колёсные арки
	for x in [-0.9, 0.9]:
		for z in [-1.45, 1.4]:
			parts.append(MeshKit.box(Vector3(0.06, 0.44, 0.85), Vector3(x, 0.55, z), trim))
	MeshKit.inst(parts, self)
	door = Node3D.new()
	door.position = Vector3(-0.9, 0.0, -0.9)
	add_child(door)
	MeshKit.inst([MeshKit.box(Vector3(0.05, 0.6, 1.15), Vector3(-0.005, 0.64, 0.58), body_c.lightened(0.03)),
		MeshKit.box(Vector3(0.05, 0.3, 1.0), Vector3(-0.005, 1.0, 0.6), dark),
		MeshKit.box(Vector3(0.06, 0.04, 0.2), Vector3(-0.02, 0.78, 1.0), Color("c9ced6"))], door)
	_extras()
	# фары
	var head: Array = [
		MeshKit.box(Vector3(0.42, 0.17, 0.06), Vector3(-0.62, 0.78, -2.31)),
		MeshKit.box(Vector3(0.42, 0.17, 0.06), Vector3(0.62, 0.78, -2.31))]
	MeshKit.glow_inst(head, Color("fff2b0"), self, 1.2)
	var tail: Array = [
		MeshKit.box(Vector3(0.4, 0.2, 0.05), Vector3(-0.66, 0.85, 2.32)),
		MeshKit.box(Vector3(0.4, 0.2, 0.05), Vector3(0.66, 0.85, 2.32))]
	tail_glow = MeshKit.glow_inst(tail, Color("c01818"), self, 0.8)
	for x in [-0.62, 0.62]:
		var sl := SpotLight3D.new()
		sl.position = Vector3(x, 0.85, -2.4)
		sl.rotation_degrees = Vector3(-4, 0, 0)
		sl.spot_range = 30.0
		sl.spot_angle = 38.0
		sl.light_energy = 2.6
		sl.light_color = Color("fff2c8")
		sl.visible = false
		add_child(sl)
		spots.append(sl)
	# колёса
	for x in [-0.88, 0.88]:
		for z in [-1.45, 1.4]:
			var piv := Node3D.new()
			piv.position = Vector3(x, 0.34, z)
			add_child(piv)
			var spin := Node3D.new()
			piv.add_child(spin)
			var wp: Array = [
				MeshKit.cyl(0.34, 0.34, 0.24, Vector3.ZERO, Color("15151a"), Vector3(0, 0, PI / 2), 14),
				MeshKit.cyl(0.2, 0.2, 0.26, Vector3.ZERO, Color("c9ced6"), Vector3(0, 0, PI / 2), 8),
				MeshKit.box(Vector3(0.27, 0.06, 0.36), Vector3.ZERO, Color("8a8f98"))]
			MeshKit.inst(wp, spin)
			wheels_all.append(spin)
			if z < 0:
				wheels_front.append(piv)
	# брёвна на крыше
	roof_logs = Node3D.new()
	roof_logs.position = Vector3(0, 1.56, 0.42)
	add_child(roof_logs)
	# дым из-под капота
	smoke = CPUParticles3D.new()
	smoke.position = Vector3(0, 1.15, -1.6)
	smoke.amount = 18
	smoke.lifetime = 2.2
	smoke.direction = Vector3(0, 1, 0)
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.8
	smoke.initial_velocity_max = 1.6
	smoke.gravity = Vector3(0, 0.3, 0)
	smoke.scale_amount_min = 0.5
	smoke.scale_amount_max = 1.3
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	sm.radial_segments = 8
	sm.rings = 4
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.2, 0.2, 0.2, 0.55)
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smat
	smoke.mesh = sm
	add_child(smoke)


func _extras() -> void:
	var x: Array = []
	match kind:
		"sport":
			x.append(MeshKit.box(Vector3(1.7, 0.06, 0.5), Vector3(0, 1.28, 2.2), Color("15151a")))
			for sx in [-0.7, 0.7]:
				x.append(MeshKit.box(Vector3(0.06, 0.28, 0.3), Vector3(sx, 1.14, 2.2), Color("15151a")))
			x.append(MeshKit.box(Vector3(0.3, 0.02, 4.4), Vector3(-0.3, 1.0, 0), Color("15151a")))
			x.append(MeshKit.box(Vector3(0.3, 0.02, 4.4), Vector3(0.3, 1.0, 0), Color("15151a")))
		"uaz":
			x.append(MeshKit.cyl(0.38, 0.38, 0.2, Vector3(0, 0.95, 2.45), Color("15151a"), Vector3(PI / 2, 0, 0), 12))
			for sx in [-0.7, 0.7]:
				x.append(MeshKit.box(Vector3(0.05, 0.05, 2.6), Vector3(sx, 1.52, 0.42), Color("2a2a2a")))
			x.append(MeshKit.box(Vector3(1.6, 0.05, 2.6), Vector3(0, 1.5, 0.42), Color("3a3a3a")))
		"police":
			x.append(MeshKit.box(Vector3(1.8, 0.2, 0.7), Vector3(0, 0.78, -0.2), Color("2a4fa8")))
			x.append(MeshKit.box(Vector3(1.8, 0.18, 0.7), Vector3(0, 0.78, 1.5), Color("2a4fa8")))
			x.append(MeshKit.box(Vector3(1.0, 0.1, 0.3), Vector3(0, 1.45, 0.2), Color("222222")))
			var a := MeshKit.glow_inst([MeshKit.box(Vector3(0.42, 0.12, 0.26), Vector3(-0.26, 1.54, 0.2))], Color("ff2a2a"), self, 3.0)
			var b := MeshKit.glow_inst([MeshKit.box(Vector3(0.42, 0.12, 0.26), Vector3(0.26, 1.54, 0.2))], Color("2a6aff"), self, 3.0)
			siren_a = a
			siren_b = b
			siren_light = OmniLight3D.new()
			siren_light.position = Vector3(0, 2.0, 0.2)
			siren_light.omni_range = 9.0
			siren_light.light_energy = 3.0
			add_child(siren_light)
	if not x.is_empty():
		MeshKit.inst(x, self)


func _update_logs() -> void:
	var n := mini(logs_on_roof, 12)
	if n == shown_logs:
		return
	shown_logs = n
	for c in roof_logs.get_children():
		c.queue_free()
	if n <= 0:
		return
	var parts: Array = []
	for i in n:
		var row := i % 4
		var layer := i / 4
		var x := -0.5 + row * 0.33 + (0.16 if layer % 2 == 1 else 0.0)
		parts.append(MeshKit.cyl(0.15, 0.15, 2.3, Vector3(x, 0.15 + layer * 0.27, 0), Color("8a5a2b"), Vector3(PI / 2, 0, 0), 8))
		parts.append(MeshKit.cyl(0.12, 0.12, 0.02, Vector3(x, 0.15 + layer * 0.27, -1.16), Color("c98f4f"), Vector3(PI / 2, 0, 0), 8))
	MeshKit.inst(parts, roof_logs)


func drive(throttle: float, steer: float, delta: float) -> void:
	if abs(throttle) > 0.12:
		var tgt := throttle * (max_fwd if throttle > 0.0 else MAX_REV)
		speed = move_toward(speed, tgt, acc * delta)
	else:
		speed = move_toward(speed, 0.0, 9.0 * delta)
	var turn := clampf(speed / 5.0, -1.0, 1.0)
	rotation.y -= steer * 1.9 * turn * delta
	var fwd := -global_transform.basis.z
	velocity = fwd * speed
	velocity.y = -3.0
	move_and_slide()
	speed = velocity.dot(fwd) if get_slide_collision_count() > 0 else speed
	steer_vis = lerpf(steer_vis, steer, clampf(8.0 * delta, 0.0, 1.0))


func _process(delta: float) -> void:
	_update_logs()
	if siren_a != null:
		siren_t += delta
		var on := int(siren_t * 6.0) % 2 == 0
		siren_a.visible = on
		siren_b.visible = not on
		siren_light.light_color = Color("ff2a2a") if on else Color("2a6aff")
	smoke.emitting = not fixed
	wheel_spin += speed * delta / 0.34
	for w in wheels_all:
		w.rotation.x = -wheel_spin
	for p in wheels_front:
		p.rotation.y = -steer_vis * 0.5
	if shake_t > 0.0:
		shake_t = maxf(0.0, shake_t - delta)
		rotation.z = sin(shake_t * 70.0) * shake_t * 0.05
	else:
		rotation.z = 0.0


func set_lights(on: bool) -> void:
	for l in spots:
		l.visible = on

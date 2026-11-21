class_name Heli3D
extends Node3D
## Вертолёт: полицейский (преследует, светит прожектором, стреляет) или городской (кружит).

var kind := "police"
var hp := 300.0
var rotor: Node3D
var tail_rotor: Node3D
var light: SpotLight3D
var t := 0.0
var vel := Vector3.ZERO
var shoot_t := 2.0
var dying := false
var fall_v := 0.0
var orbit_c := Vector3.ZERO
var orbit_r := 40.0


func _ready() -> void:
	var white := Color("e9edf2") if kind == "police" else Color("d83a2a")
	var parts: Array = [
		MeshKit.box(Vector3(2.0, 1.6, 3.4), Vector3(0, 0, 0), white),
		MeshKit.sph(1.15, Vector3(0, -0.05, -1.5), white, Vector3(1.0, 0.85, 1.1), 10),
		MeshKit.box(Vector3(1.7, 0.7, 0.9), Vector3(0, 0.25, -2.0), Color("1d2a40")),
		MeshKit.box(Vector3(0.5, 0.5, 4.2), Vector3(0, 0.3, 3.6), white),
		MeshKit.box(Vector3(0.12, 1.1, 0.7), Vector3(0, 0.8, 5.5), white),
		MeshKit.box(Vector3(0.14, 0.14, 0.9), Vector3(0, 1.0, 0), Color("2a2a30")),
		MeshKit.box(Vector3(0.06, 0.06, 3.2), Vector3(-1.0, -1.1, 0), Color("2a2a30")),
		MeshKit.box(Vector3(0.06, 0.06, 3.2), Vector3(1.0, -1.1, 0), Color("2a2a30")),
		MeshKit.box(Vector3(0.06, 0.6, 0.06), Vector3(-1.0, -0.8, -0.8), Color("2a2a30")),
		MeshKit.box(Vector3(0.06, 0.6, 0.06), Vector3(1.0, -0.8, 0.8), Color("2a2a30")),
		MeshKit.box(Vector3(2.0, 0.3, 0.1), Vector3(0, 0.1, 0.4), Color("2a4fa8") if kind == "police" else Color("f2f2f2"))]
	MeshKit.inst(parts, self)
	rotor = Node3D.new()
	rotor.position = Vector3(0, 1.1, 0)
	add_child(rotor)
	MeshKit.inst([MeshKit.box(Vector3(9.0, 0.05, 0.3), Vector3.ZERO, Color("303038")),
		MeshKit.box(Vector3(0.3, 0.05, 9.0), Vector3.ZERO, Color("303038"))], rotor)
	tail_rotor = Node3D.new()
	tail_rotor.position = Vector3(0.2, 0.8, 5.5)
	add_child(tail_rotor)
	MeshKit.inst([MeshKit.box(Vector3(0.05, 1.6, 0.2), Vector3.ZERO, Color("303038"))], tail_rotor)
	if kind == "police":
		var a := MeshKit.glow_inst([MeshKit.box(Vector3(0.3, 0.14, 0.3), Vector3(-0.6, 0.85, -0.6))], Color("ff2a2a"), self, 3.0)
		var b := MeshKit.glow_inst([MeshKit.box(Vector3(0.3, 0.14, 0.3), Vector3(0.6, 0.85, -0.6))], Color("2a6aff"), self, 3.0)
		a.name = "SirenA"
		b.name = "SirenB"
		light = SpotLight3D.new()
		light.position = Vector3(0, -0.8, -1.2)
		light.spot_range = 48.0
		light.spot_angle = 13.0
		light.light_energy = 7.0
		light.light_color = Color("fff6d8")
		light.shadow_enabled = false
		add_child(light)


func _process(delta: float) -> void:
	t += delta
	rotor.rotation.y += delta * 40.0
	tail_rotor.rotation.x += delta * 40.0
	if kind == "police" and has_node("SirenA"):
		var on := int(t * 6.0) % 2 == 0
		(get_node("SirenA") as Node3D).visible = on
		(get_node("SirenB") as Node3D).visible = not on


## Полёт за целью. Вернёт true при выстреле.
func think(delta: float, tp: Vector3, night: bool) -> bool:
	if dying:
		fall_v += 14.0 * delta
		global_position.y -= fall_v * delta
		rotation.z += delta * 2.5
		rotation.y += delta * 3.0
		return false
	var want := tp + Vector3(cos(t * 0.45) * 13.0, 17.0, sin(t * 0.45) * 13.0)
	var d := want - global_position
	vel = vel.lerp(d.limit_length(18.0) * 0.9, clampf(1.6 * delta, 0.0, 1.0))
	global_position += vel * delta
	var look := tp - global_position
	look.y = 0.0
	if look.length() > 0.5:
		rotation.y = lerp_angle(rotation.y, atan2(-look.x, -look.z), clampf(2.5 * delta, 0.0, 1.0))
	rotation.x = lerpf(rotation.x, clampf(vel.length() * 0.012, 0.0, 0.18), clampf(2.0 * delta, 0.0, 1.0))
	if light != null:
		light.visible = night
		var lp := tp + Vector3(0, 0.5, 0)
		if (lp - light.global_position).length() > 1.0:
			light.look_at(lp, Vector3.UP)
	shoot_t -= delta
	if shoot_t <= 0.0 and global_position.distance_to(tp) < 36.0:
		shoot_t = randf_range(1.0, 1.7)
		return true
	return false


## Облёт вокруг точки (городской вертолёт).
func orbit(delta: float) -> void:
	var a := t * 0.12
	var want := orbit_c + Vector3(cos(a) * orbit_r, 38.0, sin(a) * orbit_r)
	var d := want - global_position
	global_position += d.limit_length(14.0 * delta * 3.0) * 0.5 if d.length() > 30.0 else Vector3(-sin(a), 0, cos(a)) * orbit_r * 0.12 * delta
	global_position.y = lerpf(global_position.y, want.y, clampf(delta, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, atan2(sin(a), cos(a)) + PI, clampf(delta, 0.0, 1.0))


func hurt(dmg: float) -> bool:
	if dying:
		return false
	hp -= dmg
	if hp <= 0.0:
		dying = true
		return true
	return false

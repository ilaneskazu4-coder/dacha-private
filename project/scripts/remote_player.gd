class_name RemotePlayer
extends Node3D
## Другой игрок по сети: человечек с именем над головой, плавно догоняет позицию из сети.

const SWING_TIME := 0.5
const HATS := ["beanie", "cap", "kerchief", "none"]
const HAT_COLS := [Color("e08a1e"), Color("2f7ad0"), Color("c43a6a"), Color("3a3a3a")]

var peer_id := 0
var hum: Humanoid
var label: Label3D
var car_vis: Car3D
var net_pos := Vector3.ZERO
var net_face := 0.0
var net_spd := 0.0
var flags := 0
var face := 0.0
var swing_t := -1.0
var first := true
var dead := false
var in_car := false
var shown_name := ""


## Внешность игрока по номеру в комнате (0 — классический Михалыч).
static func style(idx: int) -> Dictionary:
	if idx == 0:
		return {"skin": Color("e7b48a"), "shirt": Color("b3261e"), "pants": Color("2f4a7a"),
			"shoes": Color("4a2d1c"), "hat": "beanie", "hat_col": Color("e08a1e"),
			"beard": true, "beard_col": Color("6b4423"), "stripes": true}
	var shirts: Array = Net.COLORS
	return {"skin": Color("e7b48a"), "shirt": shirts[idx % shirts.size()], "pants": Color("2f4a7a"),
		"shoes": Color("4a2d1c"), "hat": HATS[idx % HATS.size()], "hat_col": HAT_COLS[idx % HAT_COLS.size()],
		"beard": idx % 2 == 0, "beard_col": Color("6b4423"), "stripes": false}


func setup(id: int, nm: String, idx: int) -> void:
	peer_id = id
	shown_name = nm
	name = "Remote%d" % id
	add_to_group("remote_players")
	hum = HeroRig.new()
	var st := style(idx)
	hum.setup({"tint": Color.WHITE if idx == 0 else Color.WHITE.lerp(st.get("shirt", Color.WHITE), 0.5)})
	add_child(hum)
	var parts: Array = [
		MeshKit.cyl(0.032, 0.032, 0.95, Vector3(0, -0.72, 0), Color("7a4a24"), Vector3.ZERO, 6),
		MeshKit.box(Vector3(0.06, 0.2, 0.32), Vector3(0, -1.12, -0.12), Color("c9ced6"))]
	MeshKit.inst(parts, hum.arm_r)
	label = Label3D.new()
	label.text = nm
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.006
	label.font_size = 56
	label.outline_size = 14
	label.modulate = Color("ffe08a")
	label.outline_modulate = Color(0, 0, 0, 0.9)
	label.position = Vector3(0, 2.45, 0)
	label.no_depth_test = true
	label.fixed_size = false
	add_child(label)
	car_vis = Car3D.new()
	car_vis.fixed = true
	add_child(car_vis)
	car_vis.collision_layer = 0
	car_vis.collision_mask = 0
	car_vis.visible = false
	car_vis.set_physics_process(false)


func net_update(pos: Vector3, f: float, spd: float, fl: int) -> void:
	net_pos = pos
	net_face = f
	net_spd = spd
	flags = fl
	if first:
		first = false
		global_position = pos
		face = f


func _process(delta: float) -> void:
	if first:
		return
	var d := net_pos - global_position
	var moved := d.length()
	if moved > 25.0:
		global_position = net_pos
	else:
		global_position = global_position.lerp(net_pos, clampf(12.0 * delta, 0.0, 1.0))
	face = lerp_angle(face, net_face, clampf(12.0 * delta, 0.0, 1.0))
	dead = (flags & 4) != 0
	in_car = (flags & 2) != 0
	car_vis.visible = in_car
	hum.visible = not in_car
	label.position.y = 3.2 if in_car else 2.45
	if in_car:
		car_vis.speed = net_spd
		car_vis.rotation.y = net_face
		return
	hum.rotation.y = face
	hum.dance = (flags & 8) != 0
	if dead or (flags & 16) != 0:
		hum.rotation.z = lerpf(hum.rotation.z, 1.45, clampf(8.0 * delta, 0.0, 1.0))
		hum.position.y = 0.0
		return
	hum.rotation.z = lerpf(hum.rotation.z, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	if (flags & 1) != 0 and swing_t < 0.0:
		swing_t = 0.0
	if swing_t >= 0.0:
		swing_t += delta
		if swing_t >= SWING_TIME:
			swing_t = -1.0
	hum.air = (flags & 32) != 0
	hum.vy = 0.0
	hum.swing_angle = _swing_pose() if swing_t >= 0.0 else NAN
	hum.animate(delta, net_spd)


func _swing_pose() -> float:
	var k := swing_t / SWING_TIME
	if k < 0.4:
		return lerpf(0.2, 2.9, smoothstep(0.0, 1.0, k / 0.4))
	return lerpf(2.9, 1.15, smoothstep(0.0, 1.0, (k - 0.4) / 0.25))

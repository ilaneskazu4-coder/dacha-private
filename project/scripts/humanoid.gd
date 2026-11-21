class_name Humanoid
extends Node3D
## Человечек из примитивов с ходьбой, танцем и взмахом топора. Смотрит в -Z.

var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var phase := 0.0
var t := 0.0
var dance := false
var excite := 0.0
var swing_angle := NAN
var rnd := randf() * TAU
var top_y := 2.0
var rest_arm := 0.12


func setup(s: Dictionary) -> void:
	var skin: Color = s.get("skin", Color("e0b48a"))
	var shirt: Color = s.get("shirt", Color("5577aa"))
	var pants: Color = s.get("pants", Color("3a3a48"))
	var shoes: Color = s.get("shoes", Color("2a1a10"))
	var hat: String = s.get("hat", "none")
	var hat_col: Color = s.get("hat_col", Color("333333"))
	var hair: Color = s.get("hair", Color("3a2a1a"))
	var beard: bool = s.get("beard", false)
	var beard_col: Color = s.get("beard_col", Color("cccccc"))
	var shades: bool = s.get("shades", false)
	var skirt: bool = s.get("skirt", false)
	var skirt_col: Color = s.get("skirt_col", pants)
	var stripes: bool = s.get("stripes", false)
	var suit: bool = s.get("suit", false)
	var sparkle: bool = s.get("sparkle", false)
	var sc: float = s.get("scale", 1.0)
	scale = Vector3(sc, sc, sc)
	top_y = 2.0 * sc

	var body: Array = []
	# торс и ремень
	body.append(MeshKit.box(Vector3(0.52, 0.64, 0.3), Vector3(0, 1.12, 0), shirt))
	body.append(MeshKit.box(Vector3(0.54, 0.07, 0.32), Vector3(0, 0.82, 0), pants.darkened(0.45)))
	body.append(MeshKit.box(Vector3(0.08, 0.07, 0.04), Vector3(0, 0.82, -0.17), Color("d4a93a")))
	if stripes:
		for i in 5:
			body.append(MeshKit.box(Vector3(0.535, 0.035, 0.31), Vector3(0, 0.92 + i * 0.12, 0), shirt.darkened(0.5)))
		for i in 4:
			body.append(MeshKit.box(Vector3(0.035, 0.62, 0.31), Vector3(-0.18 + i * 0.12, 1.12, 0), shirt.darkened(0.5)))
	if suit:
		body.append(MeshKit.box(Vector3(0.14, 0.42, 0.02), Vector3(0, 1.2, -0.155), Color("f2f2f2")))
		body.append(MeshKit.box(Vector3(0.05, 0.36, 0.025), Vector3(0, 1.17, -0.165), Color("a01a2a")))
	if skirt:
		body.append(MeshKit.cyl(0.27, 0.54, 0.85, Vector3(0, 0.5, 0), skirt_col, Vector3.ZERO, 16))
	if sparkle:
		for i in 7:
			var a := i * 0.9
			body.append(MeshKit.sph(0.025, Vector3(sin(a) * 0.2, 0.7 + i * 0.1, -0.2 + cos(a) * 0.04), Color.WHITE, Vector3.ONE, 6))
	# голова
	body.append(MeshKit.sph(0.19, Vector3(0, 1.62, 0), skin, Vector3(1, 1.08, 1), 14))
	body.append(MeshKit.box(Vector3(0.07, 0.07, 0.07), Vector3(0, 1.58, -0.19), skin.darkened(0.06)))
	if shades:
		body.append(MeshKit.box(Vector3(0.33, 0.07, 0.06), Vector3(0, 1.66, -0.16), Color.BLACK))
	else:
		body.append(MeshKit.sph(0.028, Vector3(-0.07, 1.66, -0.175), Color.BLACK, Vector3.ONE, 6))
		body.append(MeshKit.sph(0.028, Vector3(0.07, 1.66, -0.175), Color.BLACK, Vector3.ONE, 6))
	if beard:
		body.append(MeshKit.box(Vector3(0.3, 0.22, 0.22), Vector3(0, 1.5, -0.07), beard_col))
		body.append(MeshKit.box(Vector3(0.2, 0.05, 0.05), Vector3(0, 1.57, -0.19), beard_col.darkened(0.1)))
	if hat == "none" or hat == "plume":
		body.append(MeshKit.sph(0.2, Vector3(0, 1.68, 0.03), hair, Vector3(1, 0.8, 1.05), 10))
	# головные уборы
	match hat:
		"cap":
			body.append(MeshKit.cyl(0.2, 0.21, 0.12, Vector3(0, 1.8, 0), hat_col))
			body.append(MeshKit.box(Vector3(0.28, 0.03, 0.2), Vector3(0, 1.75, -0.22), hat_col.darkened(0.2)))
		"beanie":
			body.append(MeshKit.sph(0.215, Vector3(0, 1.74, 0), hat_col, Vector3(1, 0.85, 1.05), 12))
			body.append(MeshKit.sph(0.07, Vector3(0, 1.95, 0), hat_col.lightened(0.5), Vector3.ONE, 8))
		"kerchief":
			body.append(MeshKit.sph(0.215, Vector3(0, 1.71, 0.02), hat_col, Vector3(1, 0.8, 1.08), 12))
			body.append(MeshKit.box(Vector3(0.12, 0.12, 0.1), Vector3(0, 1.62, 0.22), hat_col))
		"plume":
			body.append(MeshKit.cyl(0.2, 0.2, 0.05, Vector3(0, 1.8, 0), hat_col))
			var cols := [Color("ff4f9a"), Color("ffd23a"), Color("4fd0ff")]
			for i in 3:
				body.append(MeshKit.cyl(0.0, 0.06, 0.4, Vector3(-0.12 + i * 0.12, 2.03, 0), cols[i],
					Vector3(0, 0, 0.35 - i * 0.35), 6))
	MeshKit.inst(body, self)

	# ноги
	for side in [-1, 1]:
		var piv := Node3D.new()
		piv.position = Vector3(side * 0.13, 0.8, 0)
		add_child(piv)
		var lp: Array = [
			MeshKit.box(Vector3(0.2, 0.8, 0.22), Vector3(0, -0.4, 0), pants),
			MeshKit.box(Vector3(0.22, 0.12, 0.34), Vector3(0, -0.74, -0.05), shoes)]
		MeshKit.inst(lp, piv)
		if side < 0:
			leg_l = piv
		else:
			leg_r = piv
	# руки
	for side in [-1, 1]:
		var piv := Node3D.new()
		piv.position = Vector3(side * 0.34, 1.38, 0)
		add_child(piv)
		var ap: Array = [
			MeshKit.box(Vector3(0.15, 0.6, 0.17), Vector3(0, -0.3, 0), shirt),
			MeshKit.sph(0.078, Vector3(0, -0.65, 0), skin, Vector3.ONE, 8)]
		MeshKit.inst(ap, piv)
		if side < 0:
			arm_l = piv
		else:
			arm_r = piv


func animate(delta: float, speed: float) -> void:
	t += delta
	excite = maxf(0.0, excite - delta)
	if dance:
		var sp := 5.0 + excite * 5.0
		phase += delta * sp
		position.y = absf(sin(phase + rnd)) * (0.04 + excite * 0.16)
		arm_l.rotation = Vector3(2.5 + sin(phase * 2.0 + rnd) * 0.5, 0.0, -0.45)
		arm_r.rotation = Vector3(2.5 + cos(phase * 2.0 + rnd) * 0.5, 0.0, 0.45)
		leg_l.rotation.x = sin(phase + rnd) * 0.3
		leg_r.rotation.x = -sin(phase + rnd) * 0.3
		rotation.y = sin(phase * 0.5 + rnd) * 0.4
		return
	var amp := clampf(speed / 3.0, 0.0, 1.0)
	if speed > 0.3:
		phase += delta * (4.0 + speed * 1.6)
	else:
		phase = lerpf(phase, roundf(phase / PI) * PI, clampf(delta * 8.0, 0.0, 1.0))
	leg_l.rotation.x = sin(phase) * 0.85 * amp
	leg_r.rotation.x = -sin(phase) * 0.85 * amp
	var idle := sin(t * 1.7 + rnd) * 0.035
	arm_l.rotation = Vector3(-sin(phase) * 0.75 * amp + rest_arm + idle, 0.0, -0.06)
	arm_r.rotation = Vector3(sin(phase) * 0.75 * amp + rest_arm - idle, 0.0, 0.06)
	if not is_nan(swing_angle):
		arm_r.rotation = Vector3(swing_angle, 0.0, 0.06)
	position.y = absf(sin(phase)) * 0.05 * amp

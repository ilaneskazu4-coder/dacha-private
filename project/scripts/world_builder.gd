class_name WorldBuilder
extends RefCounted
## Строит землю, дороги, холмы и здания деревни.

const BOUNDS := Rect2(-60, -90, 170, 170)   # x, z, ширина, глубина игровой зоны


static func ground(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(700, 700)
	plane.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("4f8a3a")
	gm.roughness = 1.0
	plane.material_override = gm
	parent.add_child(plane)
	MeshKit.static_box(parent, Vector3(700, 1, 700), Vector3(0, -0.5, 0))

	# пятна травы разных оттенков
	var patches: Array = []
	for i in 90:
		var p := Vector3(rng.randf_range(-70, 120), 0.015, rng.randf_range(-100, 90))
		var c := Color("4f8a3a").lightened(rng.randf_range(-0.12, 0.1))
		patches.append(MeshKit.cyl(rng.randf_range(2.5, 7.0), 0.0 + rng.randf_range(2.5, 7.0), 0.02, p, c, Vector3.ZERO, 14))
	MeshKit.inst(patches, parent)

	# дороги
	var edge := Color("8a6f48")
	var road := Color("a98b5d")
	var roads: Array = [
		[Vector3(140, 0.06, 7.8), Vector3(25, 0.02, 0), edge],
		[Vector3(140, 0.06, 7.0), Vector3(25, 0.04, 0), road],
		[Vector3(4.8, 0.06, 7.5), Vector3(50, 0.02, -6.8), edge],
		[Vector3(4.0, 0.06, 7.0), Vector3(50, 0.04, -6.8), road],
		[Vector3(6.8, 0.06, 16.0), Vector3(72, 0.02, -7.6), edge],
		[Vector3(6.0, 0.06, 15.0), Vector3(72, 0.04, -7.6), road],
		[Vector3(4.8, 0.06, 38.0), Vector3(30, 0.02, 22.0), edge],
		[Vector3(4.0, 0.06, 37.0), Vector3(30, 0.04, 22.0), road],
		[Vector3(3.0, 0.06, 3.0), Vector3(-28, 0.02, -4.8), edge],
		[Vector3(2.4, 0.06, 2.6), Vector3(-28, 0.04, -4.8), road],
	]
	var rparts: Array = []
	for r in roads:
		rparts.append(MeshKit.box(r[0], r[1], r[2]))
	MeshKit.inst(rparts, parent)

	# цветы и камни
	var deco: Array = []
	for i in 380:
		var p := Vector3(rng.randf_range(-58, 108), 0.1, rng.randf_range(-88, 78))
		if absf(p.z) < 5.0 and p.x < 96.0:
			continue
		var fc: Color = [Color("ffd23a"), Color("ffffff"), Color("ff7aa8"), Color("9ab8ff")][i % 4]
		deco.append(MeshKit.sph(0.1, p, fc, Vector3.ONE, 5))
		deco.append(MeshKit.cyl(0.015, 0.015, 0.2, p + Vector3(0, -0.06, 0), Color("2f6b36"), Vector3.ZERO, 3))
	for i in 40:
		var p2 := Vector3(rng.randf_range(-58, 108), 0.15, rng.randf_range(-88, 78))
		deco.append(MeshKit.sph(rng.randf_range(0.2, 0.5), p2, Color("8a8f98").darkened(rng.randf_range(0.0, 0.25)), Vector3(1, 0.6, 1), 6))
	MeshKit.inst(deco, parent)

	# невидимые стены по краям
	var b := BOUNDS
	MeshKit.static_box(parent, Vector3(b.size.x + 20, 20, 2), Vector3(b.position.x + b.size.x / 2, 10, b.position.y - 1))
	MeshKit.static_box(parent, Vector3(b.size.x + 20, 20, 2), Vector3(b.position.x + b.size.x / 2, 10, b.end.y + 1))
	MeshKit.static_box(parent, Vector3(2, 20, b.size.y + 20), Vector3(b.position.x - 1, 10, b.position.y + b.size.y / 2))
	MeshKit.static_box(parent, Vector3(2, 20, b.size.y + 20), Vector3(b.end.x + 1, 10, b.position.y + b.size.y / 2))

	# холмы по периметру
	var hills: Array = []
	var n := 34
	for i in n:
		var a := float(i) / n * TAU
		var cx := b.position.x + b.size.x / 2.0 + cos(a) * (b.size.x / 2.0 + 28.0)
		var cz := b.position.y + b.size.y / 2.0 + sin(a) * (b.size.y / 2.0 + 28.0)
		var h := rng.randf_range(16.0, 34.0)
		var gc := Color("3b6a3a").darkened(rng.randf_range(0.0, 0.25))
		hills.append(MeshKit.cyl(0.0, rng.randf_range(20.0, 34.0), h, Vector3(cx, h / 2.0 - 1.0, cz), gc, Vector3.ZERO, 8))
		hills.append(MeshKit.cyl(0.0, 9.0, h * 0.28, Vector3(cx, h - 2.0, cz), Color("e8eef2"), Vector3.ZERO, 8))
	MeshKit.inst(hills, parent)


# ---------- здания ----------

static func smoke_puff(parent: Node3D, pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 10
	p.lifetime = 3.2
	p.direction = Vector3(0, 1, 0)
	p.spread = 8.0
	p.initial_velocity_min = 0.7
	p.initial_velocity_max = 1.1
	p.gravity = Vector3(0.25, 0.2, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	sm.radial_segments = 8
	sm.rings = 4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.9, 0.9, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = m
	p.mesh = sm
	parent.add_child(p)


static func _board(parent: Node3D, text: String, pos: Vector3, w: float, fs: int = 40, px: float = 0.0085) -> void:
	var parts: Array = [
		MeshKit.box(Vector3(w, 0.78, 0.14), pos, Color("3b2a1a")),
		MeshKit.box(Vector3(w - 0.2, 0.62, 0.16), pos, Color("5a4026"))]
	MeshKit.inst(parts, parent)
	MeshKit.label(text, pos + Vector3(0, 0, 0.1), Color("fff2c8"), fs, px, false, parent)


static var win_mats: Array = []
static var porch_lights: Array = []


static func house(title: String, wall: Color, roof: Color, w: float = 9.0, d: float = 7.0) -> Node3D:
	var n := Node3D.new()
	var parts: Array = []
	var panes: Array = []
	parts.append(MeshKit.box(Vector3(w, 3.2, d), Vector3(0, 1.6, 0), wall))
	for i in 7:
		parts.append(MeshKit.box(Vector3(w + 0.06, 0.07, d + 0.06), Vector3(0, 0.3 + i * 0.45, 0), wall.darkened(0.28)))
	parts.append(MeshKit.prism(Vector3(d + 1.4, 2.3, w + 1.4), Vector3(0, 3.2 + 1.15, 0), roof, Vector3(0, PI / 2, 0)))
	parts.append(MeshKit.box(Vector3(1.2, 2.2, 0.12), Vector3(0, 1.1, d / 2 + 0.03), Color("4a2d1c")))
	parts.append(MeshKit.sph(0.07, Vector3(0.4, 1.1, d / 2 + 0.12), Color("d4a93a"), Vector3.ONE, 6))
	parts.append(MeshKit.box(Vector3(2.0, 0.15, 0.9), Vector3(0, 0.07, d / 2 + 0.45), Color("8a8f98")))
	for x in [-w / 2 + 1.7, w / 2 - 1.7]:
		parts.append(MeshKit.box(Vector3(1.5, 1.3, 0.1), Vector3(x, 2.0, d / 2 + 0.03), Color("e8d9a0")))
		panes.append(MeshKit.box(Vector3(1.25, 1.05, 0.12), Vector3(x, 2.0, d / 2 + 0.04), Color.WHITE))
		parts.append(MeshKit.box(Vector3(0.06, 1.05, 0.14), Vector3(x, 2.0, d / 2 + 0.05), Color("e8d9a0")))
	for z in [-1.4, 1.4]:
		panes.append(MeshKit.box(Vector3(0.1, 1.05, 1.25), Vector3(w / 2 + 0.03, 2.0, z), Color.WHITE))
		panes.append(MeshKit.box(Vector3(0.1, 1.05, 1.25), Vector3(-w / 2 - 0.03, 2.0, z), Color.WHITE))
	parts.append(MeshKit.box(Vector3(0.9, 2.4, 0.9), Vector3(w / 2 - 1.4, 4.6, -d / 4), Color("7a6a5a")))
	MeshKit.inst(parts, n)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("2a3a4a")
	wm.emission_enabled = true
	wm.emission = Color("ffc86a")
	wm.emission_energy_multiplier = 0.0
	var gi := MeshKit.glow_inst(panes, Color.WHITE, n, 0.0)
	gi.material_override = wm
	win_mats.append(wm)
	var pl := OmniLight3D.new()
	pl.position = Vector3(0, 2.9, d / 2 + 1.6)
	pl.light_color = Color("ffc070")
	pl.light_energy = 1.0
	pl.omni_range = 9.0
	pl.visible = false
	n.add_child(pl)
	porch_lights.append(pl)
	smoke_puff(n, Vector3(w / 2 - 1.4, 5.9, -d / 4))
	_board(n, title, Vector3(0, 2.75, d / 2 + 0.08), 3.8, 38, 0.0075)
	MeshKit.static_box(n, Vector3(w, 3.4, d), Vector3(0, 1.7, 0))
	return n


static func sawmill(title: String) -> Node3D:
	var n := Node3D.new()
	var parts: Array = []
	parts.append(MeshKit.box(Vector3(14, 0.2, 9), Vector3(0, 0.1, 0), Color("7a5a38")))
	for p in [Vector2(-6.8, 4.2), Vector2(6.8, 4.2), Vector2(-6.8, -4.2), Vector2(6.8, -4.2)]:
		parts.append(MeshKit.cyl(0.22, 0.25, 3.6, Vector3(p.x, 1.9, p.y), Color("5b3a22"), Vector3.ZERO, 8))
	parts.append(MeshKit.box(Vector3(14, 3.6, 0.3), Vector3(0, 1.9, -4.35), Color("5a4630")))
	parts.append(MeshKit.box(Vector3(0.3, 3.6, 9), Vector3(-6.85, 1.9, 0), Color("5a4630")))
	parts.append(MeshKit.box(Vector3(15.2, 0.35, 10.6), Vector3(0, 3.9, 0), Color("6b3b2a"), Vector3(0.1, 0, 0)))
	parts.append(MeshKit.box(Vector3(6.0, 0.9, 1.8), Vector3(-1.5, 0.65, 0.5), Color("7a5a38")))
	parts.append(MeshKit.cyl(0.34, 0.34, 5.0, Vector3(-1.5, 1.4, 0.5), Color("8a5a2b"), Vector3(0, 0, PI / 2), 10))
	parts.append(MeshKit.cyl(0.3, 0.3, 0.02, Vector3(1.0, 1.4, 0.5), Color("c98f4f"), Vector3(0, 0, PI / 2), 10))
	MeshKit.inst(parts, n)
	# пила
	var saw := Node3D.new()
	saw.position = Vector3(-1.5, 2.1, 1.35)
	n.add_child(saw)
	var sp: Array = [MeshKit.cyl(1.0, 1.0, 0.07, Vector3.ZERO, Color("aeb4bd"), Vector3(PI / 2, 0, 0), 20),
		MeshKit.cyl(0.14, 0.14, 0.12, Vector3.ZERO, Color("555a62"), Vector3(PI / 2, 0, 0), 8)]
	for i in 16:
		var a := i * TAU / 16.0
		sp.append(MeshKit.box(Vector3(0.22, 0.22, 0.07), Vector3(cos(a) * 1.02, sin(a) * 1.02, 0), Color("c9ced6"), Vector3(0, 0, a + 0.7)))
	MeshKit.inst(sp, saw)
	n.set_meta("saw", saw)
	_board(n, title, Vector3(0, 4.6, 5.0), 4.6, 44, 0.0085)
	MeshKit.static_box(n, Vector3(14, 3.8, 9), Vector3(0, 1.9, 0))
	return n


static func garage(title: String) -> Node3D:
	var n := Node3D.new()
	var parts: Array = []
	parts.append(MeshKit.box(Vector3(10, 3.4, 8), Vector3(0, 1.7, 0), Color("8a929c")))
	parts.append(MeshKit.box(Vector3(10.6, 0.4, 8.6), Vector3(0, 3.6, 0), Color("4a4f58")))
	parts.append(MeshKit.box(Vector3(6.6, 2.7, 0.12), Vector3(0, 1.35, 4.03), Color("5a6068")))
	for i in 9:
		parts.append(MeshKit.box(Vector3(6.6, 0.07, 0.15), Vector3(0, 0.25 + i * 0.3, 4.05), Color("464b52")))
	parts.append(MeshKit.box(Vector3(1.0, 2.1, 0.1), Vector3(-4.0, 1.05, 4.03), Color("3a3f48")))
	for i in 3:
		parts.append(MeshKit.cyl(0.5, 0.5, 0.35, Vector3(6.2, 0.2 + i * 0.36, 4.6), Color("1a1a1a"), Vector3(0, 0, 0), 12))
		parts.append(MeshKit.cyl(0.22, 0.22, 0.37, Vector3(6.2, 0.2 + i * 0.36, 4.6), Color("5a5a5a"), Vector3(0, 0, 0), 8))
	parts.append(MeshKit.cyl(0.4, 0.4, 1.0, Vector3(-6.2, 0.5, 4.4), Color("a02020"), Vector3.ZERO, 10))
	MeshKit.inst(parts, n)
	_board(n, title, Vector3(0, 3.0, 4.1), 3.8, 38, 0.0075)
	MeshKit.static_box(n, Vector3(10, 3.6, 8), Vector3(0, 1.8, 0))
	return n


static func club_front() -> Node3D:
	var n := Node3D.new()
	var w := 20.0
	var d := 12.0
	var parts: Array = []
	parts.append(MeshKit.box(Vector3(w, 6.5, d), Vector3(0, 3.25, 0), Color("2a1238")))
	for i in 7:
		parts.append(MeshKit.box(Vector3(0.7, 6.5, 0.4), Vector3(-9.0 + i * 3.0, 3.25, d / 2 + 0.2), Color("3a1a4e")))
	parts.append(MeshKit.box(Vector3(w + 0.8, 0.5, d + 0.8), Vector3(0, 6.7, 0), Color("120818")))
	parts.append(MeshKit.box(Vector3(3.2, 3.3, 0.2), Vector3(0, 1.65, d / 2 + 0.1), Color("d4a93a")))
	parts.append(MeshKit.box(Vector3(2.8, 3.0, 0.24), Vector3(0, 1.5, d / 2 + 0.1), Color("0c0612")))
	parts.append(MeshKit.box(Vector3(0.06, 3.0, 0.28), Vector3(0, 1.5, d / 2 + 0.1), Color("d4a93a")))
	parts.append(MeshKit.sph(0.1, Vector3(-0.3, 1.4, d / 2 + 0.28), Color("e8c23a"), Vector3.ONE, 6))
	parts.append(MeshKit.sph(0.1, Vector3(0.3, 1.4, d / 2 + 0.28), Color("e8c23a"), Vector3.ONE, 6))
	parts.append(MeshKit.box(Vector3(3.4, 0.05, 5.5), Vector3(0, 0.05, d / 2 + 2.9), Color("b01a35")))
	for s in [-1, 1]:
		for z in [1.2, 3.4, 5.4]:
			parts.append(MeshKit.cyl(0.05, 0.05, 1.0, Vector3(s * 2.0, 0.5, d / 2 + z), Color("e8c23a"), Vector3.ZERO, 6))
			parts.append(MeshKit.sph(0.1, Vector3(s * 2.0, 1.02, d / 2 + z), Color("e8c23a"), Vector3.ONE, 6))
	# енот-логотип над крышей
	var lc := Vector3(0, 9.0, d / 2 - 1.2)
	parts.append(MeshKit.sph(1.7, lc, Color("c9c4d6"), Vector3(1, 0.95, 0.65), 14))
	parts.append(MeshKit.sph(0.6, lc + Vector3(-1.25, 1.55, 0), Color("c9c4d6"), Vector3(1, 1, 0.5), 8))
	parts.append(MeshKit.sph(0.6, lc + Vector3(1.25, 1.55, 0), Color("c9c4d6"), Vector3(1, 1, 0.5), 8))
	parts.append(MeshKit.box(Vector3(3.2, 0.75, 0.3), lc + Vector3(0, 0.2, 1.0), Color("3a2a4a")))
	parts.append(MeshKit.sph(0.28, lc + Vector3(-0.7, 0.2, 1.2), Color.WHITE, Vector3.ONE, 8))
	parts.append(MeshKit.sph(0.28, lc + Vector3(0.7, 0.2, 1.2), Color.WHITE, Vector3.ONE, 8))
	parts.append(MeshKit.sph(0.1, lc + Vector3(-0.7, 0.2, 1.45), Color.BLACK, Vector3.ONE, 6))
	parts.append(MeshKit.sph(0.1, lc + Vector3(0.7, 0.2, 1.45), Color.BLACK, Vector3.ONE, 6))
	parts.append(MeshKit.sph(0.32, lc + Vector3(0, -0.55, 1.15), Color("ff6fb5"), Vector3(1, 0.8, 0.8), 8))
	MeshKit.inst(parts, n)
	var glowp: Array = []
	for x in [-8.0, -5.5, 5.5, 8.0]:
		glowp.append(MeshKit.box(Vector3(0.35, 3.0, 0.1), Vector3(x, 2.6, d / 2 + 0.45)))
	MeshKit.glow_inst(glowp, Color("ff4fa8"), n, 2.2)
	var neon := MeshKit.label("ДИСКО ЕНОТ", Vector3(0, 4.9, d / 2 + 0.55), Color("ff5fb0"), 110, 0.012, false, n)
	neon.shaded = false
	neon.outline_size = 36
	neon.outline_modulate = Color(1, 0.2, 0.6, 0.45)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 4.0, d / 2 + 4.0)
	light.light_color = Color("ff5fb0")
	light.omni_range = 16.0
	light.light_energy = 1.6
	light.name = "NeonLight"
	n.add_child(light)
	MeshKit.static_box(n, Vector3(w, 7, d), Vector3(0, 3.5, 0))
	return n


static func sign_post(text: String) -> Node3D:
	var n := Node3D.new()
	MeshKit.inst([MeshKit.cyl(0.07, 0.09, 2.0, Vector3(0, 1.0, 0), Color("5b3a22"), Vector3.ZERO, 6),
		MeshKit.box(Vector3(2.6, 0.55, 0.1), Vector3(0, 1.85, 0), Color("3b5a2a")),
		MeshKit.box(Vector3(2.45, 0.42, 0.12), Vector3(0, 1.85, 0), Color("4a7034"))], n)
	MeshKit.label(text, Vector3(0, 1.85, 0.08), Color("fff2c8"), 38, 0.0065, false, n)
	MeshKit.static_cyl(n, 0.12, 2.0, Vector3(0, 1.0, 0))
	return n


static func log_pile() -> Node3D:
	var n := Node3D.new()
	var parts: Array = []
	for row in 4:
		for i in (5 - row):
			var x := -1.2 + i * 0.6 + row * 0.3
			parts.append(MeshKit.cyl(0.28, 0.28, 3.0, Vector3(x, 0.3 + row * 0.5, 0), Color("8a5a2b"), Vector3(PI / 2, 0, 0), 8))
			parts.append(MeshKit.cyl(0.22, 0.22, 0.02, Vector3(x, 0.3 + row * 0.5, -1.51), Color("c98f4f"), Vector3(PI / 2, 0, 0), 8))
	MeshKit.inst(parts, n)
	MeshKit.static_box(n, Vector3(3.2, 2.0, 3.0), Vector3(0.0, 1.0, 0))
	return n

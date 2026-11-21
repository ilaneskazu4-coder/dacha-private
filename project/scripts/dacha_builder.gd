class_name DachaBuilder
extends RefCounted
## Карта 280 x 280 м: земля, тропы, дача с забором, огород, колодец, озеро, вышка, холмы.

const HALF := 140.0
const LAKE_C := Vector3(98, 0, 12)
const LAKE_R := 28.0
const DACHA := Rect2(-22, -28, 44, 48)    # x, z, ширина, глубина (с забором)


static func ground(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var plane := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	plane.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("4f8a3a")
	gm.roughness = 1.0
	plane.material_override = gm
	parent.add_child(plane)
	MeshKit.static_box(parent, Vector3(900, 1, 900), Vector3(0, -0.5, 0))

	var patches: Array = []
	for i in 70:
		# у каждого пятна своя высота: иначе перекрывающиеся диски мерцают (z-fighting)
		var p := Vector3(rng.randf_range(-150, 150), 0.006 + i * 0.0003, rng.randf_range(-150, 150))
		var c := Color("4f8a3a").lightened(rng.randf_range(-0.12, 0.1))
		var r := rng.randf_range(3.0, 9.0)
		patches.append(MeshKit.cyl(r, r, 0.02, p, c, Vector3.ZERO, 14))
	MeshKit.inst(patches, parent)

	# тропы от калитки
	var edge := Color("8a6f48")
	var road := Color("a98b5d")
	var paths: Array = [
		[Vector3(4.6, 0.06, 90.0), Vector3(0, 0.02, 60.0)],
		[Vector3(90.0, 0.06, 4.6), Vector3(45.0, 0.02, 60.0)],
		[Vector3(90.0, 0.06, 4.6), Vector3(-45.0, 0.02, 60.0)],
		[Vector3(4.6, 0.06, 70.0), Vector3(-90.0, 0.02, 25.0)],
		[Vector3(4.6, 0.06, 80.0), Vector3(90.0, 0.02, 20.0)],
	]
	var pparts: Array = []
	for pth in paths:
		var sz: Vector3 = pth[0]
		var pos: Vector3 = pth[1]
		pparts.append(MeshKit.box(sz, pos, edge))
		pparts.append(MeshKit.box(Vector3(sz.x - (0.6 if sz.x < 10.0 else 0.0), 0.07, sz.z - (0.6 if sz.z < 10.0 else 0.0)), pos + Vector3(0, 0.02, 0), road))
	MeshKit.inst(pparts, parent)

	# цветы и камни вокруг дачи
	var deco: Array = []
	for i in 420:
		var p := Vector3(rng.randf_range(-48, 48), 0.1, rng.randf_range(-40, 70))
		var fc: Color = [Color("ffd23a"), Color("ffffff"), Color("ff7aa8"), Color("9ab8ff")][i % 4]
		deco.append(MeshKit.sph(0.1, p, fc, Vector3.ONE, 5))
		deco.append(MeshKit.cyl(0.015, 0.015, 0.2, p + Vector3(0, -0.06, 0), Color("2f6b36"), Vector3.ZERO, 3))
	MeshKit.inst(deco, parent)

	# невидимые стены по краям карты
	var h := HALF
	MeshKit.static_box(parent, Vector3(2 * h + 20, 20, 2), Vector3(0, 10, -h - 1))
	MeshKit.static_box(parent, Vector3(2 * h + 20, 20, 2), Vector3(0, 10, h + 1))
	MeshKit.static_box(parent, Vector3(2, 20, 2 * h + 20), Vector3(-h - 1, 10, 0))
	MeshKit.static_box(parent, Vector3(2, 20, 2 * h + 20), Vector3(h + 1, 10, 0))

	# холмы вокруг карты
	var hills: Array = []
	var n := 46
	for i in n:
		var a := float(i) / n * TAU
		var cx := cos(a) * (h + 34.0)
		var cz := sin(a) * (h + 34.0)
		var hh := rng.randf_range(20.0, 42.0)
		var gc := Color("3b6a3a").darkened(rng.randf_range(0.0, 0.25))
		hills.append(MeshKit.cyl(0.0, rng.randf_range(24.0, 40.0), hh, Vector3(cx, hh / 2.0 - 1.0, cz), gc, Vector3.ZERO, 8))
		hills.append(MeshKit.cyl(0.0, 10.0, hh * 0.28, Vector3(cx, hh - 2.0, cz), Color("e8eef2"), Vector3.ZERO, 8))
	MeshKit.inst(hills, parent)


static func lake(parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = LAKE_R
	cm.bottom_radius = LAKE_R
	cm.height = 0.08
	cm.radial_segments = 32
	cm.rings = 1
	mi.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.15, 0.45, 0.75, 0.82)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.15
	m.metallic = 0.3
	m.emission_enabled = true
	m.emission = Color(0.05, 0.2, 0.4)
	mi.material_override = m
	mi.position = LAKE_C + Vector3(0, 0.05, 0)
	parent.add_child(mi)
	# берег и камыши
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var parts: Array = []
	for i in 60:
		var a := rng.randf() * TAU
		var r := LAKE_R + rng.randf_range(-0.5, 1.4)
		var p := LAKE_C + Vector3(cos(a) * r, 0.5, sin(a) * r)
		parts.append(MeshKit.cyl(0.03, 0.03, 1.1, p, Color("6a8a3a"), Vector3.ZERO, 3))
		parts.append(MeshKit.cyl(0.07, 0.07, 0.25, p + Vector3(0, 0.55, 0), Color("5a3a22"), Vector3.ZERO, 4))
	for i in 18:
		var a2 := rng.randf() * TAU
		var r2 := LAKE_R + rng.randf_range(1.0, 3.0)
		parts.append(MeshKit.sph(rng.randf_range(0.4, 0.9), LAKE_C + Vector3(cos(a2) * r2, 0.2, sin(a2) * r2), Color("8a8f98"), Vector3(1, 0.7, 1), 6))
	MeshKit.inst(parts, parent)
	MeshKit.static_cyl(parent, LAKE_R - 0.5, 4.0, LAKE_C + Vector3(0, 1.0, 0))


static func fence(parent: Node3D) -> void:
	var parts: Array = []
	var x0 := DACHA.position.x + 2.0
	var x1 := DACHA.end.x - 2.0
	var z0 := DACHA.position.y + 2.0
	var z1 := DACHA.end.y - 4.0
	var wood := Color("a8814a")
	var dark := Color("6b4a2a")
	var segs: Array = [
		[Vector2(x0, z0), Vector2(x1, z0)],
		[Vector2(x0, z0), Vector2(x0, z1)],
		[Vector2(x1, z0), Vector2(x1, z1)],
		[Vector2(x0, z1), Vector2(-3.0, z1)],
		[Vector2(3.0, z1), Vector2(x1, z1)],
	]
	for s in segs:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var len := a.distance_to(b)
		var steps := int(len / 2.0)
		var dir := (b - a).normalized()
		var yaw := atan2(-dir.y, dir.x)
		for i in steps + 1:
			var p := a + dir * (i * 2.0)
			parts.append(MeshKit.box(Vector3(0.18, 1.5, 0.18), Vector3(p.x, 0.75, p.y), dark))
		for k in 2:
			var mid := (a + b) * 0.5
			parts.append(MeshKit.box(Vector3(len, 0.12, 0.08), Vector3(mid.x, 0.55 + k * 0.5, mid.y), wood, Vector3(0, yaw, 0)))
		var m2 := (a + b) * 0.5
		var sz := Vector3(len, 1.4, 0.4) if absf(dir.x) > 0.5 else Vector3(0.4, 1.4, len)
		MeshKit.static_box(parent, sz, Vector3(m2.x, 0.7, m2.y))
	# калитка: столбы
	for gx in [-3.0, 3.0]:
		parts.append(MeshKit.box(Vector3(0.3, 2.0, 0.3), Vector3(gx, 1.0, z1), dark))
		parts.append(MeshKit.sph(0.2, Vector3(gx, 2.1, z1), Color("d4a93a"), Vector3.ONE, 6))
	MeshKit.inst(parts, parent)


static func garden(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var parts: Array = []
	for bed in [Vector3(-11, 0, -16), Vector3(-11, 0, -11), Vector3(11, 0, -17), Vector3(11, 0, -12)]:
		parts.append(MeshKit.box(Vector3(6.0, 0.3, 2.2), bed + Vector3(0, 0.15, 0), Color("5a3a22")))
		parts.append(MeshKit.box(Vector3(6.2, 0.1, 0.12), bed + Vector3(0, 0.32, 1.1), Color("8a6a3a")))
		parts.append(MeshKit.box(Vector3(6.2, 0.1, 0.12), bed + Vector3(0, 0.32, -1.1), Color("8a6a3a")))
		for i in 8:
			var x := -2.6 + i * 0.75
			parts.append(MeshKit.cyl(0.0, 0.2, 0.5, bed + Vector3(x, 0.55, rng.randf_range(-0.5, 0.5)), Color("3f8a3a"), Vector3.ZERO, 5))
			if i % 3 == 0:
				parts.append(MeshKit.sph(0.14, bed + Vector3(x, 0.4, 0.6), Color("d93a2a"), Vector3.ONE, 6))
	MeshKit.inst(parts, parent)


static func well(parent: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var parts: Array = [
		MeshKit.cyl(0.9, 0.9, 0.9, Vector3(0, 0.45, 0), Color("8a8f98"), Vector3.ZERO, 12),
		MeshKit.cyl(0.65, 0.65, 0.05, Vector3(0, 0.88, 0), Color("1a3a5a"), Vector3.ZERO, 12),
		MeshKit.box(Vector3(0.14, 1.9, 0.14), Vector3(-0.85, 1.4, 0), Color("5b3a22")),
		MeshKit.box(Vector3(0.14, 1.9, 0.14), Vector3(0.85, 1.4, 0), Color("5b3a22")),
		MeshKit.prism(Vector3(2.4, 0.8, 2.0), Vector3(0, 2.7, 0), Color("7a3b2a"), Vector3(0, PI / 2, 0)),
		MeshKit.cyl(0.05, 0.05, 1.9, Vector3(0, 2.1, 0), Color("c98f4f"), Vector3(0, 0, PI / 2), 6)]
	MeshKit.inst(parts, n)
	MeshKit.static_cyl(n, 1.0, 1.2, Vector3(0, 0.6, 0))


static func tower(parent: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var parts: Array = []
	for p in [Vector2(-2, -2), Vector2(2, -2), Vector2(-2, 2), Vector2(2, 2)]:
		parts.append(MeshKit.cyl(0.18, 0.28, 11.0, Vector3(p.x, 5.5, p.y), Color("5a4a3a"), Vector3.ZERO, 6))
	for lv in [3.0, 7.0]:
		parts.append(MeshKit.box(Vector3(4.6, 0.15, 0.15), Vector3(0, lv, -2), Color("5a4a3a")))
		parts.append(MeshKit.box(Vector3(4.6, 0.15, 0.15), Vector3(0, lv, 2), Color("5a4a3a")))
		parts.append(MeshKit.box(Vector3(0.15, 0.15, 4.6), Vector3(-2, lv, 0), Color("5a4a3a")))
		parts.append(MeshKit.box(Vector3(0.15, 0.15, 4.6), Vector3(2, lv, 0), Color("5a4a3a")))
	parts.append(MeshKit.cyl(3.0, 3.0, 3.6, Vector3(0, 12.8, 0), Color("a0623a"), Vector3.ZERO, 14))
	parts.append(MeshKit.cyl(0.0, 3.3, 1.6, Vector3(0, 15.4, 0), Color("6a3a2a"), Vector3.ZERO, 14))
	MeshKit.inst(parts, n)
	MeshKit.static_box(n, Vector3(4.6, 11, 4.6), Vector3(0, 5.5, 0))
	MeshKit.label("ВЫШКА", Vector3(0, 13.0, 3.1), Color("fff2c8"), 64, 0.014, false, n)

class_name Forest
extends Node3D
## Лес и камни. Отрисовка через MultiMesh (один вызов на вид), у каждого дерева свой коллайдер.
## Деревья падают, оставляют пни и отрастают заново.

const RESPAWN := 70.0

var items: Array = []
var mm_by_variant := {}     # вариант -> [MultiMesh, число занятых]
var meshes := {}            # вариант -> ArrayMesh
var stump_mm: MultiMesh
var dead: Array = []
var tree_shape := CylinderShape3D.new()
var rock_shape := CylinderShape3D.new()


static func variant_parts(v: int) -> Array:
	var trunk := Color("5b3a22")
	var parts: Array = []
	match v:
		0, 1:
			var g := Color("2f6b36") if v == 0 else Color("3b7d3f")
			parts.append(MeshKit.cyl(0.2, 0.32, 2.4, Vector3(0, 1.2, 0), trunk, Vector3.ZERO, 7))
			parts.append(MeshKit.cyl(0.0, 1.7, 2.2, Vector3(0, 2.6, 0), g.darkened(0.12), Vector3.ZERO, 8))
			parts.append(MeshKit.cyl(0.0, 1.35, 2.0, Vector3(0, 3.75, 0), g, Vector3.ZERO, 8))
			parts.append(MeshKit.cyl(0.0, 0.95, 1.7, Vector3(0, 4.8, 0), g.lightened(0.1), Vector3.ZERO, 8))
		2:
			parts.append(MeshKit.cyl(0.14, 0.2, 3.4, Vector3(0, 1.7, 0), Color("e8e4d8"), Vector3.ZERO, 7))
			for i in 4:
				parts.append(MeshKit.box(Vector3(0.18, 0.06, 0.05), Vector3(0.0, 0.5 + i * 0.7, -0.17), Color("2a2a2a")))
			parts.append(MeshKit.sph(1.25, Vector3(0, 3.9, 0), Color("5f9a45"), Vector3(1, 1.1, 1), 8))
			parts.append(MeshKit.sph(0.9, Vector3(0.8, 3.3, 0.3), Color("6aa84f"), Vector3.ONE, 7))
			parts.append(MeshKit.sph(0.85, Vector3(-0.75, 3.4, -0.3), Color("4f8a3a"), Vector3.ONE, 7))
		3:
			parts.append(MeshKit.cyl(0.3, 0.42, 2.5, Vector3(0, 1.25, 0), Color("6b4a2a"), Vector3.ZERO, 7))
			parts.append(MeshKit.sph(1.6, Vector3(0, 3.7, 0), Color("3f7a3a"), Vector3(1, 0.9, 1), 8))
			parts.append(MeshKit.sph(1.1, Vector3(1.1, 3.1, 0.4), Color("4a8a40"), Vector3.ONE, 7))
			parts.append(MeshKit.sph(1.0, Vector3(-1.0, 3.2, -0.5), Color("356f33"), Vector3.ONE, 7))
		4:
			parts.append(MeshKit.sph(0.9, Vector3(0, 0.5, 0), Color("7d838c"), Vector3(1.2, 0.8, 1.0), 7))
			parts.append(MeshKit.sph(0.55, Vector3(0.7, 0.3, 0.3), Color("8d939c"), Vector3(1, 0.8, 1), 6))
		_:
			parts.append(MeshKit.sph(0.8, Vector3(0, 0.45, 0), Color("6d737c"), Vector3(1.0, 0.85, 1.3), 7))
			parts.append(MeshKit.sph(0.5, Vector3(-0.6, 0.25, -0.3), Color("9a8f86"), Vector3(1, 0.8, 1), 6))
	return parts


func build(rng: RandomNumberGenerator, tree_count: int, rock_count: int, ok: Callable, half: float) -> void:
	tree_shape.radius = 0.4
	tree_shape.height = 3.0
	rock_shape.radius = 0.85
	rock_shape.height = 1.4
	var placed: Array = []
	var want := tree_count + rock_count
	var tries := 0
	while items.size() < want and tries < 40000:
		tries += 1
		var p := Vector3(rng.randf_range(-half + 4.0, half - 4.0), 0.0, rng.randf_range(-half + 4.0, half - 4.0))
		if not ok.call(p):
			continue
		var bad := false
		for q in placed:
			if Vector2(q.x - p.x, q.z - p.z).length_squared() < 9.0:
				bad = true
				break
		if bad:
			continue
		placed.append(p)
		var is_tree := items.size() < tree_count
		var v := (rng.randi() % 4) if is_tree else (4 + rng.randi() % 2)
		items.append({"kind": "tree" if is_tree else "rock", "v": v, "pos": p,
			"sc": rng.randf_range(0.85, 1.35) if is_tree else rng.randf_range(0.8, 1.5),
			"yaw": rng.randf() * TAU, "hp": 3 if is_tree else 4, "alive": true,
			"respawn": 0.0, "idx": 0, "sidx": -1, "k": ""})
		var itn: Dictionary = items[items.size() - 1]
		itn["k"] = "%d_%d_%d" % [v, int(floorf((p.x + 200.0) / 48.0)), int(floorf((p.z + 200.0) / 48.0))]
	# счётчики по видам
	var counts := {}
	for it in items:
		counts[it["k"]] = counts.get(it["k"], 0) + 1
	var shared_mat := MeshKit.mat()
	for k in counts:
		var v: int = int(String(k).split("_")[0])
		if not meshes.has(v):
			meshes[v] = MeshKit.build(variant_parts(v))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[v]
		mm.instance_count = counts[k]
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = shared_mat
		mmi.visibility_range_end = 150.0
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		add_child(mmi)
		mm_by_variant[k] = [mm, 0]
	var trees_n := 0
	for it in items:
		if it["kind"] == "tree":
			trees_n += 1
	stump_mm = MultiMesh.new()
	stump_mm.transform_format = MultiMesh.TRANSFORM_3D
	stump_mm.mesh = MeshKit.build([
		MeshKit.cyl(0.3, 0.38, 0.5, Vector3(0, 0.25, 0), Color("5b3a22"), Vector3.ZERO, 7),
		MeshKit.cyl(0.29, 0.29, 0.03, Vector3(0, 0.51, 0), Color("c98f4f"), Vector3.ZERO, 7)])
	stump_mm.instance_count = trees_n
	var smi := MultiMeshInstance3D.new()
	smi.multimesh = stump_mm
	smi.material_override = MeshKit.mat()
	add_child(smi)
	var si := 0
	for i in items.size():
		var it: Dictionary = items[i]
		var entry: Array = mm_by_variant[it["k"]]
		it["idx"] = entry[1]
		entry[1] += 1
		(entry[0] as MultiMesh).set_instance_transform(it["idx"], _xf(it))
		if it["kind"] == "tree":
			it["sidx"] = si
			stump_mm.set_instance_transform(si, Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(0, -50, 0)))
			si += 1
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = tree_shape if it["kind"] == "tree" else rock_shape
		cs.position.y = 1.5 if it["kind"] == "tree" else 0.6
		sb.position = it["pos"]
		sb.add_child(cs)
		add_child(sb)
		it["shape"] = cs


func _xf(it: Dictionary) -> Transform3D:
	var b := Basis(Vector3.UP, it["yaw"]).scaled(Vector3.ONE * it["sc"])
	return Transform3D(b, it["pos"])


func _hide(it: Dictionary) -> void:
	var entry: Array = mm_by_variant[it["k"]]
	(entry[0] as MultiMesh).set_instance_transform(it["idx"], Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(it["pos"].x, -50, it["pos"].z)))


## Удар по ближайшему ресурсу вблизи точки. Возвращает {} если ничего нет.
func hit_at(origin: Vector3, radius: float, from: Vector3) -> Dictionary:
	var best := -1
	var bd := radius
	for i in items.size():
		var it: Dictionary = items[i]
		if not it["alive"]:
			continue
		var p: Vector3 = it["pos"]
		var d := Vector2(p.x - origin.x, p.z - origin.z).length()
		if d < bd:
			bd = d
			best = i
	if best < 0:
		return {}
	return hit_idx(best, from)


## Удар по ресурсу с известным номером (нужен и для ударов других игроков по сети).
func hit_idx(best: int, from: Vector3) -> Dictionary:
	var it: Dictionary = items[best]
	if not it["alive"]:
		return {}
	it["hp"] -= 1
	var res := {"kind": it["kind"], "pos": it["pos"], "felled": false, "i": best}
	if it["hp"] > 0:
		return res
	it["alive"] = false
	it["respawn"] = RESPAWN
	dead.append(best)
	(it["shape"] as CollisionShape3D).set_deferred("disabled", true)
	_hide(it)
	res["felled"] = true
	if it["kind"] == "tree":
		var pos: Vector3 = it["pos"]
		stump_mm.set_instance_transform(it["sidx"], Transform3D(Basis(Vector3.UP, it["yaw"]), pos))
		_fall_visual(it, from)
	return res


func _fall_visual(it: Dictionary, from: Vector3) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = meshes[it["v"]]
	mi.material_override = MeshKit.mat()
	add_child(mi)
	var pos: Vector3 = it["pos"]
	var sc: float = it["sc"]
	var dir := pos - from
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var axis := Vector3.UP.cross(dir).normalized()
	var yaw: float = it["yaw"]
	mi.position = pos
	var tw := create_tween()
	tw.tween_method(func(a: float):
		mi.transform = Transform3D(Basis(axis, a) * Basis(Vector3.UP, yaw).scaled(Vector3.ONE * sc), pos),
		0.0, 1.5, 0.9).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_interval(1.2)
	tw.tween_callback(mi.queue_free)


func _process(delta: float) -> void:
	if dead.is_empty():
		return
	for i in range(dead.size() - 1, -1, -1):
		var it: Dictionary = items[dead[i]]
		it["respawn"] -= delta
		if it["respawn"] <= 0.0:
			it["alive"] = true
			it["hp"] = 3 if it["kind"] == "tree" else 4
			var entry: Array = mm_by_variant[it["k"]]
			(entry[0] as MultiMesh).set_instance_transform(it["idx"], _xf(it))
			(it["shape"] as CollisionShape3D).set_deferred("disabled", false)
			if it["sidx"] >= 0:
				stump_mm.set_instance_transform(it["sidx"], Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3(0, -50, 0)))
			dead.remove_at(i)


func nearest_alive(origin: Vector3, radius: float) -> bool:
	for it in items:
		if it["alive"]:
			var p: Vector3 = it["pos"]
			if Vector2(p.x - origin.x, p.z - origin.z).length() < radius:
				return true
	return false

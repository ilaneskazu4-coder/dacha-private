extends SceneTree
## Запекание весов Джейсона: godot --headless --path . --script res://scripts/_bake_jason.gd  (источник: assets/jason/jason_src.res)
func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _init() -> void:
	var srcm := load("res://tools_src/jason_src.res") as ArrayMesh
	var arrays := srcm.surface_get_arrays(0)
	var nv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var nu: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var ni: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var segs: Dictionary = CharDefs.SEGS_C
	var nvx := nv.size()
	var dense := PackedFloat32Array()
	dense.resize(nvx * 17)
	for i in nvx:
		var p := nv[i]
		var side := signf(p.x) if absf(p.x) > 0.03 else 0.0
		var tot := 0.0
		for b in 17:
			var is_p := (b >= 5 and b <= 7) or (b >= 11 and b <= 13)
			var is_n := (b >= 8 and b <= 10) or (b >= 14 and b <= 16)
			if (is_p and side < 0.0) or (is_n and side > 0.0):
				continue
			var d := 1e9
			for sg in segs[b]:
				d = minf(d, seg_dist(p, sg[0], sg[1]))
			var w := 1.0 / pow(d + 0.035, 3.0)
			if b == 5 or b == 8:
				w *= smoothstep(0.16, 0.3, absf(p.x))
			elif b == 6 or b == 7 or b == 9 or b == 10:
				w *= smoothstep(0.38, 0.52, absf(p.x))
			dense[i * 17 + b] = w
			tot += w
		for b in 17:
			dense[i * 17 + b] /= maxf(tot, 1e-9)
	var keymap := {}
	var rep := PackedInt32Array()
	rep.resize(nvx)
	for i in nvx:
		var k := Vector3i((nv[i] * 400.0).round())
		if not keymap.has(k):
			keymap[k] = i
		rep[i] = keymap[k]
	var nbr := {}
	for t in range(0, ni.size(), 3):
		for e in 3:
			var a0: int = rep[ni[t + e]]
			var b0: int = rep[ni[t + (e + 1) % 3]]
			if a0 == b0:
				continue
			if not nbr.has(a0): nbr[a0] = {}
			if not nbr.has(b0): nbr[b0] = {}
			nbr[a0][b0] = true
			nbr[b0][a0] = true
	for it in 5:
		var nd := dense.duplicate()
		for i in nvx:
			if rep[i] != i or not nbr.has(i):
				continue
			var ns: Array = nbr[i].keys()
			for b in 17:
				var sum := 0.0
				for n in ns:
					sum += dense[n * 17 + b]
				var sm := 0.5 * (1.0 - smoothstep(0.3, 0.4, absf(nv[i].x)))
				nd[i * 17 + b] = dense[i * 17 + b] * (1.0 - sm) + sum / ns.size() * sm
		for i in nvx:
			if rep[i] != i:
				for b in 17:
					nd[i * 17 + b] = nd[rep[i] * 17 + b]
		dense = nd
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(nvx * 4)
	weights.resize(nvx * 4)
	for i in nvx:
		var ds: Array = []
		for b in 17:
			ds.append([dense[i * 17 + b], b])
		ds.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
		var tot := 0.0
		for k in 4:
			tot += ds[k][0]
		for k in 4:
			bones[i * 4 + k] = ds[k][1]
			weights[i * 4 + k] = ds[k][0] / maxf(tot, 1e-9)
	var out_arr := []
	out_arr.resize(Mesh.ARRAY_MAX)
	out_arr[Mesh.ARRAY_VERTEX] = nv
	out_arr[Mesh.ARRAY_NORMAL] = nn
	out_arr[Mesh.ARRAY_TEX_UV] = nu
	out_arr[Mesh.ARRAY_INDEX] = ni
	out_arr[Mesh.ARRAY_BONES] = bones
	out_arr[Mesh.ARRAY_WEIGHTS] = weights
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arr)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/jason/jason_tex.png")
	m.roughness = 0.85
	m.metallic = 0.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	out.surface_set_material(0, m)
	ResourceSaver.save(out, "res://assets/jason/jason_mesh.res")
	print("BAKE ok verts=", nv.size())
	quit()

extends SceneTree
## Пересчёт весов героя B по уже запечённой сетке (backup: hero2_mesh_src.res). godot --headless --path . --script res://scripts/_rebake_w2.gd
func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _init() -> void:
	var srcm := load("res://assets/hero2/hero2_mesh_src.res") as ArrayMesh
	var arrays := srcm.surface_get_arrays(0)
	var nv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var nu: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var ni: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var segs: Dictionary = CharDefs.SEGS_B
	# утолщение предплечий (+14%) и кистей (+12%): руки на беге были тонкими
	var ob: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var ow: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	for i in nv.size():
		var bi := ob[i * 4]
		var bw := ow[i * 4]
		for k in 4:
			if ow[i * 4 + k] > bw:
				bw = ow[i * 4 + k]
				bi = ob[i * 4 + k]
		var fac := 1.0
		if bi == 6 or bi == 9:
			fac = 1.14
		elif bi == 7 or bi == 10:
			fac = 1.12
		if fac != 1.0 and absf(nv[i].x) > 0.3:
			var sg: Array = segs[bi][0]
			var ab: Vector3 = sg[1] - sg[0]
			var t := clampf((nv[i] - sg[0]).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
			var proj: Vector3 = sg[0] + ab * t
			nv[i] = proj + (nv[i] - proj) * fac
			if bi == 7 or bi == 10:   # кулак: пальцы укорочены к ладони
				var tu: float = (nv[i] - sg[0]).dot(ab) / maxf(ab.length_squared(), 0.000001)
				nv[i] = sg[0] + ab * (tu * 0.78) + (nv[i] - proj)
	var nvx := nv.size()
	var dense := PackedFloat32Array()
	dense.resize(nvx * 17)
	for i in nvx:
		var p := nv[i]
		var side := signf(p.x) if absf(p.x) > 0.025 else 0.0
		var tot := 0.0
		for b in 17:
			# запрет влияния костей противоположной стороны (штанина не тянет вторую ногу, рукав — вторую руку)
			var is_p := (b >= 5 and b <= 7) or (b >= 11 and b <= 13)
			var is_n := (b >= 8 and b <= 10) or (b >= 14 and b <= 16)
			if (is_p and side < 0.0) or (is_n and side > 0.0):
				continue
			var d := 1e9
			for sg in segs[b]:
				d = minf(d, seg_dist(p, sg[0], sg[1]))
			var w := 1.0 / pow(d + 0.035, 3.0)
			if b == 5 or b == 8:      # плечо: мягкий переход от корпуса к руке
				w *= smoothstep(0.15, 0.3, absf(p.x))
			elif b == 6 or b == 7 or b == 9 or b == 10:
				w *= smoothstep(0.2, 0.34, absf(p.x))
			dense[i * 17 + b] = w
			tot += w
		for b in 17:
			dense[i * 17 + b] /= maxf(tot, 1e-9)
	# сглаживание весов по соседям (сварка вершин по позиции, чтобы швы UV не рвали веса)
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
	for it in 6:
		var nd := dense.duplicate()
		for i in nvx:
			if rep[i] != i or not nbr.has(i):
				continue
			var ns: Array = nbr[i].keys()
			for b in 17:
				var sum := 0.0
				for n in ns:
					sum += dense[n * 17 + b]
				var sm := 0.5 * (1.0 - smoothstep(0.24, 0.32, absf(nv[i].x)))   # руки не сглаживаем в торс: иначе худеют
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
	out.surface_set_material(0, srcm.surface_get_material(0))
	ResourceSaver.save(out, "res://assets/hero2/hero2_mesh.res")
	print("REBAKE ok verts=", nv.size())
	quit()

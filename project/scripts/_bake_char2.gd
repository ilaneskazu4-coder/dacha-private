extends SceneTree
## Запекание героя B: упрощение сетки (LOD) + веса костей.
## godot --headless --path . --script res://scripts/_bake_char2.gd   (дважды: после первой записи текстуры нужен --import)
func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/hero2")
	if not FileAccess.file_exists("res://assets/hero2/hero2_tex.png.import"):
		var img := Image.load_from_file("/home/claude/hero2_tex_src.png")
		img.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/hero2/hero2_tex.png")
		print("BAKE2 texture written, run import then run again")
		quit()
		return
	var root := (load("res://assets/hero2_src/b.fbx") as PackedScene).instantiate()
	var src: MeshInstance3D = root.get_child(0)
	var xf: Transform3D = src.transform
	var arrays := src.mesh.surface_get_arrays(0)
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var lod_i := 2
	var idx: PackedInt32Array = im.get_surface_lod_indices(0, lod_i)
	print("BAKE2 lod tris=", idx.size() / 3)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var remap := {}
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nu := PackedVector2Array()
	var ni := PackedInt32Array()
	var nbasis := xf.basis.inverse().transposed()
	var minp := Vector3(1e9, 1e9, 1e9)
	for v in verts:
		minp = minp.min(xf * v)
	for k in idx:
		if not remap.has(k):
			remap[k] = nv.size()
			var p: Vector3 = xf * verts[k]
			p.y -= minp.y
			nv.append(p)
			nn.append((nbasis * nrm[k]).normalized())
			nu.append(uv[k])
		ni.append(remap[k])
	var segs: Dictionary = CharDefs.SEGS_B
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
				nd[i * 17 + b] = dense[i * 17 + b] * 0.5 + sum / ns.size() * 0.5
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
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/hero2/hero2_tex.png")
	mat.roughness = 1.0
	mat.metallic_specular = 0.2
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	out.surface_set_material(0, mat)
	print("BAKE2 verts=", nv.size(), " aabb=", out.get_aabb())
	ResourceSaver.save(out, "res://assets/hero2/hero2_mesh.res")
	quit()

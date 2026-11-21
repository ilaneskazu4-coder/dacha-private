extends SceneTree
## Запекает веса скелета в сетку героя: godot --headless --path . --script res://scripts/_bake_hero.gd
const SEGS := {
	0: [[Vector3(-0.14, 0.72, 0), Vector3(0.14, 0.72, 0)], [Vector3(-0.14, 0.62, 0), Vector3(0.14, 0.62, 0)]],
	1: [[Vector3(-0.2, 0.84, 0), Vector3(0.2, 0.84, 0)]],
	2: [[Vector3(-0.22, 0.98, 0), Vector3(0.22, 0.98, 0)], [Vector3(-0.22, 1.1, 0), Vector3(0.22, 1.1, 0)]],
	3: [[Vector3(0, 1.2, 0), Vector3(0, 1.3, 0)]],
	4: [[Vector3(0, 1.34, 0), Vector3(0, 1.72, 0)], [Vector3(0, 1.8, 0), Vector3(0, 1.9, 0)]],
	5: [[Vector3(0.31, 1.17, 0), Vector3(0.52, 1.17, 0)]],
	6: [[Vector3(0.52, 1.17, 0), Vector3(0.73, 1.17, 0)]],
	7: [[Vector3(0.73, 1.17, 0), Vector3(0.88, 1.17, 0)]],
	8: [[Vector3(-0.31, 1.17, 0), Vector3(-0.52, 1.17, 0)]],
	9: [[Vector3(-0.52, 1.17, 0), Vector3(-0.73, 1.17, 0)]],
	10: [[Vector3(-0.73, 1.17, 0), Vector3(-0.88, 1.17, 0)]],
	11: [[Vector3(0.115, 0.68, 0), Vector3(0.115, 0.36, 0)]],
	12: [[Vector3(0.115, 0.36, 0), Vector3(0.115, 0.1, 0)]],
	13: [[Vector3(0.115, 0.1, 0), Vector3(0.115, 0.03, 0.1)]],
	14: [[Vector3(-0.115, 0.68, 0), Vector3(-0.115, 0.36, 0)]],
	15: [[Vector3(-0.115, 0.36, 0), Vector3(-0.115, 0.1, 0)]],
	16: [[Vector3(-0.115, 0.1, 0), Vector3(-0.115, 0.03, 0.1)]]}


func seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


func _init() -> void:
	var step: int = 1 if FileAccess.file_exists("res://assets/hero/hero_tex.png.import") else 0
	if step == 0:
		var img := Image.load_from_file("res://assets/hero/lumberjack_tex.png")
		img.resize(1024, 1024, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/hero/hero_tex.png")
		print("BAKE texture written, run import then run this again")
		quit()
		return
	var ps: PackedScene = load("res://assets/hero/lumberjack.fbx")
	var root := ps.instantiate()
	var src: MeshInstance3D = root.get_child(0)
	var xf: Transform3D = src.transform
	print("BAKE src transform ", xf)
	var mesh := src.mesh
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n := verts.size()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(n * 4)
	weights.resize(n * 4)
	var newv := PackedVector3Array()
	newv.resize(n)
	var minp := Vector3(1e9, 1e9, 1e9)
	var nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var nbasis := xf.basis.inverse().transposed()
	for k in nrm.size():
		nrm[k] = (nbasis * nrm[k]).normalized()
	arrays[Mesh.ARRAY_NORMAL] = nrm
	for v in verts:
		minp = minp.min(xf * v)
	var nb := 17
	for i in n:
		var p: Vector3 = xf * verts[i]
		p.y -= minp.y
		p.x -= 0.0
		newv[i] = p
		var ds: Array = []
		for b in nb:
			var d := 1e9
			for sg in SEGS[b]:
				d = minf(d, seg_dist(p, sg[0], sg[1]))
			ds.append([1.0 / pow(d + 0.02, 4.0), b])
		ds.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
		var tot := 0.0
		for k in 4:
			tot += ds[k][0]
		for k in 4:
			bones[i * 4 + k] = ds[k][1]
			weights[i * 4 + k] = ds[k][0] / tot
	arrays[Mesh.ARRAY_VERTEX] = newv
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_TANGENT] = null
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/hero/hero_tex.png")
	mat.roughness = 1.0
	mat.metallic_specular = 0.2
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	out.surface_set_material(0, mat)
	print("BAKE verts=", n, " min=", minp, " aabb=", out.get_aabb())
	ResourceSaver.save(out, "res://assets/hero/hero_mesh.res")
	quit()

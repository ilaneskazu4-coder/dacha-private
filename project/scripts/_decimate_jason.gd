extends SceneTree
## Упрощение сетки Джейсона через LOD-индексы meshoptimizer (ImporterMesh.generate_lods)
func _init() -> void:
	var src := load("res://tools_src/jason_src.res") as ArrayMesh
	var arrays := src.surface_get_arrays(0)
	var im := ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays)
	im.generate_lods(25.0, 60.0, [])
	var lods := im.get_surface_lod_count(0)
	print("LODS ", lods, " base tris=", (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
	var pick := -1
	for l in lods:
		var idx := im.get_surface_lod_indices(0, l)
		print("  lod ", l, " tris=", idx.size() / 3, " size=", im.get_surface_lod_size(0, l))
	var want := int(OS.get_environment("LOD")) if OS.has_environment("LOD") else 0
	var idx := im.get_surface_lod_indices(0, want)
	var nv: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var nu: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var remap := {}
	var v2 := PackedVector3Array(); var n2 := PackedVector3Array(); var u2 := PackedVector2Array(); var i2 := PackedInt32Array()
	for k in idx:
		if not remap.has(k):
			remap[k] = v2.size()
			v2.append(nv[k]); n2.append(nn[k]); u2.append(nu[k])
		i2.append(remap[k])
	var out_arr := []
	out_arr.resize(Mesh.ARRAY_MAX)
	out_arr[Mesh.ARRAY_VERTEX] = v2
	out_arr[Mesh.ARRAY_NORMAL] = n2
	out_arr[Mesh.ARRAY_TEX_UV] = u2
	out_arr[Mesh.ARRAY_INDEX] = i2
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arr)
	ResourceSaver.save(out, "res://tools_src/jason_src.res")
	print("DECIM ok verts=", v2.size(), " tris=", i2.size() / 3)
	quit()

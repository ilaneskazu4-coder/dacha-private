extends SceneTree
## FBX Джейсона -> ArrayMesh в метрах, ноги на y=0, x по центру (res://assets/jason/jason_src.res) + дамп вершин для анализа
func _init() -> void:
	var n = (load("res://assets/jason/jason.fbx") as PackedScene).instantiate()
	var mi: MeshInstance3D = n.get_node("Mesh_0")
	var xf: Transform3D = mi.transform
	var arr := mi.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var mn := Vector3(1e9, 1e9, 1e9)
	var mx := Vector3(-1e9, -1e9, -1e9)
	for i in v.size():
		v[i] = xf * v[i]
		nn[i] = (xf.basis * nn[i]).normalized()
		mn = mn.min(v[i]); mx = mx.max(v[i])
	var off := Vector3(-(mn.x + mx.x) * 0.5, -mn.y, 0.0)
	# центр по глубине — по середине корпуса (талия)
	var zs := 0.0; var zc := 0
	for p in v:
		if p.y + off.y > 0.9 and p.y + off.y < 1.1 and absf(p.x) < 0.2:
			zs += p.z; zc += 1
	off.z = -zs / maxf(zc, 1)
	for i in v.size():
		v[i] += off
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nn
	arr.resize(Mesh.ARRAY_MAX)
	for k in [Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV2]:
		arr[k] = null
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	ResourceSaver.save(out, "res://assets/jason/jason_src.res")
	var f := FileAccess.open("/home/claude/jason_in/verts.bin", FileAccess.WRITE)
	f.store_buffer(v.to_byte_array())
	f.close()
	print("PREP ok verts=", v.size(), " idx=", (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), " off=", off)
	quit()

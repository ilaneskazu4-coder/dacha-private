extends SceneTree
func _init() -> void:
	var m := load("res://assets/hero2/hero2_mesh.res") as ArrayMesh
	var a := m.surface_get_arrays(0)
	var f := FileAccess.open("/home/claude/fit/mesh.bin", FileAccess.WRITE)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	f.store_32(v.size())
	f.store_buffer(v.to_byte_array())
	var uv: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
	f.store_buffer(uv.to_byte_array())
	var b: PackedInt32Array = a[Mesh.ARRAY_BONES]
	f.store_buffer(b.to_byte_array())
	var w: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
	f.store_buffer(w.to_byte_array())
	var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	f.store_32(ix.size())
	f.store_buffer(ix.to_byte_array())
	f.close()
	quit()

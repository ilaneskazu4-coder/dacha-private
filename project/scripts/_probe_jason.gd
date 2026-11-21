extends SceneTree
func _init():
	var ps = load("res://assets/jason/jason.fbx")
	print("LOADED ", ps)
	if ps == null:
		quit(); return
	var n = ps.instantiate()
	_walk(n, 0)
	quit()
func _walk(n: Node, d: int):
	var s = "  ".repeat(d) + n.name + " [" + n.get_class() + "]"
	if n is MeshInstance3D:
		var m: MeshInstance3D = n
		s += " aabb=" + str(m.get_aabb()) + " surf=" + str(m.mesh.get_surface_count()) + " skel=" + str(m.skeleton) + " skin=" + str(m.skin != null)
		if m.mesh.get_surface_count() > 0:
			var mat = m.mesh.surface_get_material(0)
			s += " mat=" + str(mat)
		var arr = m.mesh.surface_get_arrays(0)
		s += " verts=" + str(arr[Mesh.ARRAY_VERTEX].size())
	if n is Skeleton3D:
		s += " bones=" + str(n.get_bone_count())
	print(s)
	for c in n.get_children():
		_walk(c, d + 1)

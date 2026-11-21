extends Node3D
func _ready():
	var ps = load("res://assets/jason/jason.fbx")
	var n = ps.instantiate()
	add_child(n)
	var mi: MeshInstance3D = n.get_node("Mesh_0")
	print("XFORM ", mi.transform, " scale ", mi.scale, " rootscale ", n.scale)
	var ab = mi.get_aabb()
	var gb = mi.global_transform * ab
	print("GLOBAL AABB ", gb)
	var sz = gb.size
	var c = gb.get_center()
	var h = max(sz.x, max(sz.y, sz.z))
	var cam = Camera3D.new(); add_child(cam)
	var l = DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-30, 30, 0)
	var env = WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.5,0.6,0.7); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.8,0.8,0.8); env.environment = e; add_child(env)
	cam.fov = 35
	for i in 4:
		var a = i * PI / 2.0
		cam.global_position = c + Vector3(sin(a), 0.1, cos(a)) * h * 2.3
		cam.look_at(c)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/jason_%d.png" % i)
	get_tree().quit()

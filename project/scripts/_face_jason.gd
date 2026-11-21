extends Node3D
func _ready():
	var h := HeroRig.new(); h.setup({"char": 2}); add_child(h)
	h.rotation.y = 0.0
	var cam := Camera3D.new(); add_child(cam); cam.fov = 25
	var l := DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-30, 150, 0)
	var env := WorldEnvironment.new(); var e := Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.5, 0.6, 0.7); e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.8, 0.8, 0.8); env.environment = e; add_child(env)
	for k in 2:
		var a := 0.0 if k == 0 else 0.9
		cam.global_position = Vector3(sin(a), 1.62, cos(a)) * 1.1
		cam.look_at(Vector3(0, 1.58, 0))
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://build/face_%d.png" % k)
	get_tree().quit()

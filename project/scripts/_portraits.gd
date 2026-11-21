extends Node3D
## Рендер портретов героев для колеса смены: assets/ui/portrait_raw_N.png (дальше маска кругом делается в PIL)
func _ready() -> void:
	var centers := [Vector3(0, 1.3, 0), Vector3(0, 1.56, 0), Vector3(0, 1.7, 0)]
	var dists := [2.6, 1.35, 1.45]
	var env := WorldEnvironment.new(); var e := Environment.new()
	e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.22, 0.24, 0.3)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.75, 0.75, 0.8)
	env.environment = e; add_child(env)
	var l := DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-25, 20, 0); l.light_energy = 1.1
	var cam := Camera3D.new(); add_child(cam); cam.fov = 22
	for id in 3:
		var h := HeroRig.new(); h.setup({"char": id}); add_child(h)
		h.rotation.y = PI
		h._apply(1.0, 1.0)
		var c: Vector3 = centers[id]
		cam.global_position = c + Vector3(0.12 * dists[id] / 1.35, 0.02, dists[id])
		cam.look_at(c + Vector3(0, 0, 0))
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://assets/ui/portrait_raw_%d.png" % id)
		h.queue_free()
	get_tree().quit()

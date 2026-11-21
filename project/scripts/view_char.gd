extends Node3D
var SPD := float(OS.get_environment('SPD')) if OS.has_environment('SPD') else 5.0
func _ready() -> void:
	var env := WorldEnvironment.new(); env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR; env.environment.background_color = Color(0.45,0.5,0.55)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color = Color(0.85,0.85,0.85)
	add_child(env)
	var l := DirectionalLight3D.new(); l.rotation_degrees = Vector3(-45,30,0); add_child(l)
	var cam := Camera3D.new(); add_child(cam)
	cam.fov = 38
	cam.position = Vector3(0,0.95,3.0)
	var h := HeroRig.new(); h.setup({"char": int(OS.get_environment("CH")) if OS.has_environment("CH") else 1}); add_child(h)
	var yaw := float(OS.get_environment("VY")) if OS.has_environment("VY") else -90.0
	h.rotation.y = deg_to_rad(yaw)
	await get_tree().create_timer(0.3).timeout
	for i in 60: h.animate(0.033, SPD); await get_tree().process_frame
	for i in 36:
		h.phase = float(i) / 36.0 * TAU - 0.48
		h.animate(0.05, SPD)
		h._apply(1.0, 1.0)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/rc_%s_%s_%s_%02d.png" % [OS.get_environment("CH"), OS.get_environment("VY"), str(SPD), i])
	get_tree().quit()

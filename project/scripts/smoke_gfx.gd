extends Node
var m: Node3D
func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/%s.png" % nm)
func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
func _ready() -> void:
	m = get_parent()
	run.call_deferred()
func view(pos: Vector3, yaw: float, pitch: float, t: float, nm: String) -> void:
	m.dn.t = t
	m.dn._apply()
	m.player.global_position = pos
	m.yaw = yaw
	m.pitch = pitch
	await wait(1.2)
	await shot(nm)
func run() -> void:
	await wait(0.8)
	m.ui.dlg_active = false
	m.mode = "play"
	Game.intro_done = true
	Game.stage = 4
	m.dn.set_process(false)
	await view(Vector3(0, 0.05, 6), 0.0, 0.55, 40.0, "g_day_dacha")
	await view(Vector3(0, 0.05, 6), 0.0, 0.18, 190.0, "g_night_dacha")
	await view(Vector3(-4, 0.05, 14), 0.5, 0.25, 195.0, "g_night_dacha2")
	await view(Vector3(40, 0.05, 40), 2.4, 0.12, 145.0, "g_dusk")
	await view(Vector3(55, 0.05, 10), 0.3, 0.12, 20.0, "g_day_lake")
	get_tree().quit()

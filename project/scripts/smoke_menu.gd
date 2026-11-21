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
func run() -> void:
	await wait(1.5)
	await shot("m_main_1")
	await wait(9.0)
	await shot("m_main_2")
	m._show_page("settings")
	await wait(0.4)
	await shot("m_settings")
	Settings.quality = 2
	Settings.notify()
	await wait(0.6)
	await shot("m_settings_high")
	m._show_page("confirm")
	await wait(0.3)
	await shot("m_confirm")
	m._show_page("main")
	await wait(8.0)
	await shot("m_main_3")
	print("MENU OK")
	get_tree().quit()

extends Node
## Скриншоты меню «Играть вместе».
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
	await shot("c_main")
	m._on_action("coop", null)
	await wait(0.4)
	await shot("c_coop")
	m._on_action("host", null)
	await wait(0.6)
	await shot("c_lobby_host")
	# имитация двух друзей в комнате
	Net.players = {1: {"name": Settings.nick, "idx": 0}, 22: {"name": "Серёга", "idx": 1}, 33: {"name": "Макс", "idx": 2}}
	Net.lobby_changed.emit()
	await wait(0.4)
	await shot("c_lobby_3")
	m._on_action("leave_lobby", null)
	m._on_action("find", null)
	await wait(0.5)
	await shot("c_find_empty")
	Net.rooms = {"192.168.43.1": {"name": "Серёга", "n": 2, "t": Net.clock + 100.0}}
	await wait(0.8)
	await shot("c_find_room")
	m._on_action("back_coop", null)
	m._on_action("ip", null)
	await wait(0.5)
	m.osk.text = "192.168.43.1"
	m.osk._show_text()
	await shot("c_ip")
	m.osk._finish(false)
	m._on_action("code", null)
	await wait(0.3)
	m.osk.text = "K7QM2"
	m.osk._show_text()
	await shot("c_code")
	m.osk._finish(false)
	m._on_action("name", null)
	await wait(0.3)
	m.osk._type("Я")
	await shot("c_name")
	m.osk._finish(true)
	print("COOPMENU OK nick=", Settings.nick)
	get_tree().quit()

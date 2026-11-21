extends Node
var m: Node3D
func shot(nm: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/store/%s.png" % nm)
func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
func _ready() -> void:
	m = get_parent()
	run.call_deferred()
func run() -> void:
	await wait(0.8)
	m.ui.dlg_active = false
	m.mode = "play"
	Game.intro_done = true
	m.ui_layer.visible = false
	# день
	m.dn.t = 60.0
	m.player.global_position = Vector3(-4, 0, 2)
	m.player.face = -0.5
	m.yaw = 0.55
	m.pitch = 0.22
	m.spring.spring_length = 7.5
	await wait(0.8)
	await shot("raw_day")
	# ночь: костёр, волки, вожак
	m._spawn_struct("fire", Vector3(2, 0, 3), 0)
	m.dn.t = 200.0
	m.player.global_position = Vector3(0, 0, 3.5)
	m.player.face = PI
	m.yaw = PI + 0.15
	m.pitch = 0.2
	for k in [["boss", Vector3(3, 0, 13)], ["wolf", Vector3(-3.5, 0, 10.5)], ["pup", Vector3(7, 0, 9.5)], ["wolf", Vector3(0, 0, 9)]]:
		var wb := Wolf3D.new()
		wb.kind = k[0]
		wb.position = k[1]
		m.wolves_root.add_child(wb)
		wb.target = m.player
		wb.stun_t = 5.0
	await wait(1.2)
	await shot("raw_night")
	get_tree().quit()

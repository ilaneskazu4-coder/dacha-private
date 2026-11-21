extends Node
## Кадры Тревора из самой игры (камера за спиной): ходьба, бег, прыжок, удар.
var m: Node3D
func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/gs%s_%s.png" % [OS.get_environment("CH"), n])
func _ready() -> void:
	m = get_parent()
	run.call_deferred()
func run() -> void:
	await wait(2.5)
	Game.intro_done = true
	m.ui.dlg_active = false
	m.mode = "play"
	m.player.set_char(int(OS.get_environment("CH")) if OS.has_environment("CH") else 1)
	var C: Vector3 = m.city.C
	m.player.global_position = C + Vector3(-4, 0.05, 3)
	m.cam_rig.global_position = C + Vector3(-4, 1.6, 3)
	m.yaw = 0.0
	await wait(1.0)
	for k in 5:
		m.ui.move_override = Vector2(0, -0.35)
		await wait(0.18)
		await shot("walk_%d" % k)
	for k in 6:
		m.ui.move_override = Vector2(0, -1)
		await wait(0.14)
		await shot("run_%d" % k)
	m.ui.move_override = Vector2.ZERO
	await wait(0.6)
	await shot("idle")
	m.ui.move_override = Vector2(0, -1)
	await wait(0.6)
	m.player.velocity.y = 6.0
	for k in 4:
		await wait(0.18)
		await shot("jump_%d" % k)
	m.ui.move_override = Vector2.ZERO
	print("SHOTS done")
	get_tree().quit()

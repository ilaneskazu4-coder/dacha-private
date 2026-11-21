extends Node
## Сценарий для записи видео геймплея (--write-movie). Время идёт по кадрам, поэтому запись ровная.
var m: Node3D
var orbit := 0.0
func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout
func _ready() -> void:
	m = get_parent()
	run.call_deferred()
func _process(delta: float) -> void:
	if m != null and m.mode != "car":
		m.yaw += orbit * delta
func say_through(n: int) -> void:
	for i in n:
		await wait(1.6)
		m.ui.dlg_chars = 999
		await wait(1.4)
		m.ui._advance()
func run() -> void:
	Game.hp = 100
	m.dn.t = 20.0
	orbit = 0.0
	# 1. Вступление
	m.player.global_position = Vector3(0, 0, 8)
	m.makar.global_position = Vector3(0, 0, 10.5)
	m.yaw = 0.0
	await wait(1.0)
	await say_through(5)
	await wait(0.5)
	# 2. Рубим дерево
	var best := -1
	var bd := 1e9
	for i in m.forest.items.size():
		var it: Dictionary = m.forest.items[i]
		if it["kind"] != "tree": continue
		var d: float = (it["pos"] as Vector3).distance_to(Vector3(24, 0, 28))
		if d < bd: bd = d; best = i
	var tp: Vector3 = m.forest.items[best]["pos"]
	m.player.global_position = tp + Vector3(0, 0, 1.7)
	m.player.face = 0.0
	m.yaw = 0.4
	orbit = 0.12
	for i in 5:
		m.ui.a_pressed = true
		await wait(0.65)
	await wait(0.8)
	# 3. Стройка
	Game.wood = 16
	Game.stone = 3
	m.player.global_position = Vector3(0, 0, 3)
	m.player.face = PI
	m.yaw = PI
	orbit = 0.0
	await wait(0.6)
	m.ui.c_pressed = true
	await wait(0.8)
	m.ui.slot_tapped = 2
	await wait(1.4)
	m.ui.a_pressed = true
	await wait(0.8)
	m.ui.slot_tapped = 0
	m.player.global_position = Vector3(-4, 0, 3)
	await wait(1.0)
	m.ui.a_pressed = true
	await wait(0.6)
	m.player.global_position = Vector3(-1, 0, 3)
	await wait(0.5)
	m.ui.slot_tapped = 1
	await wait(0.8)
	m.ui.a_pressed = true
	await wait(0.6)
	m.ui.c_pressed = true
	await wait(1.0)
	# 4. Ночь и волки
	m.dn.t = 166.0
	m.player.global_position = Vector3(1, 0, 4.5)
	m.yaw = 2.7
	orbit = 0.1
	await wait(5.0)
	for w in get_tree().get_nodes_in_group("wolves"):
		(w as Node3D).global_position = Vector3(randf_range(-4, 6), 0, randf_range(11, 14))
	for i in 14:
		Game.hp = maxf(Game.hp, 60.0)
		for w in get_tree().get_nodes_in_group("wolves"):
			var wf := w as Wolf3D
			if not wf.dead and wf.global_position.distance_to(m.player.global_position) < 6.0:
				var dd: Vector3 = wf.global_position - m.player.global_position
				m.player.face = atan2(-dd.x, -dd.z)
				break
		m.ui.a_pressed = true
		if i == 5:
			m.ui.b_pressed = true
		await wait(0.55)
	# вожак
	var wb := Wolf3D.new()
	wb.kind = "boss"
	wb.position = m.player.global_position + Vector3(5, 0, 9)
	m.wolves_root.add_child(wb)
	wb.target = m.player
	wb.died.connect(m._on_wolf_died)
	for i in 8:
		Game.hp = maxf(Game.hp, 50.0)
		m.ui.a_pressed = true
		await wait(0.6)
	# 5. Смерть и возрождение за рекламу
	Game.hp = 0.0
	await wait(2.2)
	m.ui.modal_btn = "ad"
	await wait(3.5)
	# 6. Рассвет и Пассат
	m.dn.t = 254.0
	orbit = 0.0
	await wait(3.5)
	m.dn.t = 40.0
	m.player.global_position = m.car.global_position + Vector3(3.2, 0, 0)
	await wait(0.6)
	m.ui.a_pressed = true
	await wait(0.8)
	m.ui.move_override = Vector2(0, -1)
	await wait(1.5)
	m.ui.move_override = Vector2(0.5, -1)
	await wait(1.2)
	m.ui.move_override = Vector2(-0.5, -1)
	await wait(1.2)
	m.ui.move_override = Vector2(0, -1)
	await wait(1.2)
	m.ui.move_override = Vector2.ZERO
	m.car.speed = 0.0
	# 7. Дискотека и напитки
	m.mode = "play"
	m.car.occupied = false
	m.player.set_active(true)
	m.player.global_position = m.CLUB_DOOR + Vector3(0, 0, 1.2)
	m.yaw = 0.0
	await wait(0.6)
	m.ui.a_pressed = true
	await wait(2.0)
	Game.wood = 12
	m.player.global_position = m.club.global_position + Vector3(-7.5, 0.05, -1.0)
	await wait(0.8)
	for i in 4:
		m.ui.a_pressed = true
		await wait(0.9)
	m.player.global_position = m.club.global_position + Vector3(0, 0.05, 1.5)
	await wait(0.5)
	m.ui.a_pressed = true
	await wait(2.5)
	m.ui.move_override = Vector2(0.7, -0.4)
	await wait(2.2)
	m.ui.move_override = Vector2(-0.7, 0.3)
	await wait(2.2)
	m.ui.move_override = Vector2.ZERO
	await wait(1.0)
	get_tree().quit()

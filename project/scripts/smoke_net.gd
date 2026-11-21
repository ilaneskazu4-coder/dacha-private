extends Node
## Проверка игры вместе: запускается в двух копиях (хозяин и гость), каждая печатает NETTEST ... PASS/FAIL.
var m: Node3D
var role := "host"
var fails := 0
var tidx := -1
var tpos := Vector3.ZERO
var guard := Vector3.ZERO

func ok(name: String, cond: bool) -> void:
	print("NETTEST ", role, " ", "PASS " if cond else "FAIL ", name)
	if not cond:
		fails += 1

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(n: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("/home/claude/dacha3d/build/net_%s_%s.png" % [role, n])

func _ready() -> void:
	m = get_parent()
	run.call_deferred()

func run() -> void:
	role = "host" if Net.is_host else "client"
	Settings.quality = 1
	m._apply_quality()
	await wait(3.0)
	m.ui.dlg_active = false
	m.mode = "play"
	var best := 1e9
	for i in m.forest.items.size():
		var it: Dictionary = m.forest.items[i]
		if it["kind"] != "tree" or not it["alive"]:
			continue
		var d: float = (it["pos"] as Vector3).distance_to(Vector3(0, 0, -2))
		if d < best:
			best = d
			tidx = i
	tpos = m.forest.items[tidx]["pos"]
	ok("players=2 remotes=1", Net.players.size() == 2 and Net.remotes.size() == 1)
	if role == "client":
		m.player.global_position = Vector3(5, 0.05, -2)
	await wait(3.0)
	m.yaw = 0.0
	await wait(0.3)
	shot("1_meet")
	if role == "host":
		await wait(0.7)
		m.player.global_position = tpos + Vector3(0, 0, 1.7)
		m.player.face = 0.0
		for i in 4:
			m.ui.a_pressed = true
			await wait(0.6)
		await wait(1.0)
		m.dn.t = 100.0
		var kind: String = Structure3D.ORDER[0]
		m._spawn_struct(kind, Vector3(-6, 0, -6), 0)
		Net.send_build(kind, -6.0, -6.0, 0)
		await wait(1.5)
		var rp := Net.remotes.values()[0] as RemotePlayer
		ok("host sees client avatar at (5,_,-2)", rp.global_position.distance_to(Vector3(5, 0, -2)) < 2.5)
		await wait(4.0)
		m.dn.t = 168.0
		await wait(8.0)
		var cl := Net.remotes.values()[0] as RemotePlayer
		var wc := 0
		for w in get_tree().get_nodes_in_group("wolves"):
			wc += 1
			(w as Node3D).global_position = cl.global_position + Vector3(randf_range(-3, 3), 0, randf_range(2.5, 4))
		ok("host has wolves", wc > 0)
		m.player.global_position = Vector3(0, 0.05, -2)
		await wait(3.0)
		shot("2_wolves")
		await wait(5.0)
		ok("host got kill from client hit", Game.kills > 0)
	else:
		var seen := false
		for i in 60:
			await wait(0.5)
			if m.dn.t > 98.0 and m.dn.t < 130.0:
				seen = true
				break
		ok("time synced from host", seen)
		await wait(2.0)
		ok("client sees tree felled by host", not bool(m.forest.items[tidx]["alive"]))
		var rp2 := Net.remotes.values()[0] as RemotePlayer
		ok("client sees host avatar near tree", rp2.global_position.distance_to(tpos + Vector3(0, 0, 1.7)) < 3.0)
		var built := false
		for s in m.structs_root.get_children():
			if Vector2(s.position.x + 6.0, s.position.z + 6.0).length() < 0.5:
				built = true
		ok("client sees host structure", built)
		await wait(1.0)
		await wait(11.0)
		var pup := 0
		var tgt: Wolf3D = null
		for w in get_tree().get_nodes_in_group("wolves"):
			if (w as Wolf3D).puppet:
				pup += 1
				tgt = w
		ok("client has wolf puppets", pup > 0)
		shot("2_wolves")
		if tgt != null:
			tgt.hurt(100.0, m.player.global_position)
		await wait(5.0)
		ok("client got bitten by host wolf", Game.hp < 100.0)
	await wait(1.0)
	print("NETTEST ", role, " DONE fails=", fails)
	get_tree().quit()

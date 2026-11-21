extends Node
## Проверка анимаций героя: ходьба с оружием, ходьба при рубке, кулаки, прыжок, скриншоты.
var m: Node3D
var fails := 0

func ok(n: String, c: bool) -> void:
	print("HEROTEST ", "PASS " if c else "FAIL ", n)
	if not c:
		fails += 1

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/home/claude/dacha3d/build/hero_%s.png" % n)

func leg_angle() -> float:
	var h := m.player.hum as HeroRig
	return absf((h.cur[HeroRig.I_THIGH_P] as Quaternion).get_euler().x) + absf((h.cur[HeroRig.I_THIGH_N] as Quaternion).get_euler().x)

func walk_for(sec: float, dir: Vector3) -> float:
	var mx := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
		m.player.walk(dir, 0.033)
		mx = maxf(mx, leg_angle())
		await get_tree().process_frame
	return mx

func _ready() -> void:
	m = get_parent()
	await wait(3.0)
	m.set_process(false)
	m.set_physics_process(false)
	m.player.global_position = Vector3(2, 0.05, 6)
	m.cam_rig.global_position = Vector3(2, 1.6, 6)
	m.yaw = 0.0
	# 1. без оружия (топор в руке)
	var a0 := await walk_for(1.2, Vector3(0, 0, -1))
	ok("walk with axe legs move", a0 > 0.3)
	await shot("1_axe_walk")
	# 2. пистолет
	Game.has_pistol = true
	Game.ammo_p = 20
	m.player.set_weapon(1)
	var a1 := await walk_for(1.2, Vector3(0, 0, -1))
	ok("walk with pistol legs move", a1 > 0.3)
	await shot("2_pistol_walk")
	# 3. рубка на ходу
	m.player.set_weapon(0)
	m.player.swing()
	var a2 := await walk_for(0.45, Vector3(0, 0, -1))
	ok("walk while chopping legs move", a2 > 0.3)
	await shot("3_chop_walk")
	# 4. руки
	m.player.set_weapon(3)
	ok("axe hidden in hands mode", not m.player.axe_mesh.visible and not m.player.gun_mesh.visible)
	m.player.swing()
	await walk_for(0.18, Vector3.ZERO)
	await shot("4_punch")
	await walk_for(0.6, Vector3(0, 0, -1))
	await shot("5_hands_walk")
	# 5. прыжок
	print("HEROTEST dbg floor=", m.player.is_on_floor(), " down=", m.player.down_t, " hp=", Game.hp, " y=", m.player.global_position.y)
	m.player.jump()
	var peak := 0.0
	var air_seen := false
	for i in 40:
		m.player.walk(Vector3(0, 0, -0.3), 0.033)
		peak = maxf(peak, m.player.global_position.y)
		if i == 8:
			await shot("6_jump")
		if (m.player.hum as HeroRig).air:
			air_seen = true
		await get_tree().process_frame
	ok("jump rose", peak > 0.5)
	ok("air pose flagged", air_seen)
	await walk_for(0.5, Vector3.ZERO)
	ok("landed", m.player.is_on_floor())
	print("HEROTEST DONE fails=", fails, " peak=", peak)
	get_tree().quit()

extends Node
## Город «Волк с Дачи»: Биржа дров, пивная, автосалон, милиция с розыском, прохожие-брокеры, яхта.

const C := Vector3(48, 0, 76)
const SPORT_PRICE := 300
const YACHT_PRICE := 1500
const BEER_PRICE := 5
const KEEP_LOGS := 10
const PISTOL_PRICE := 150
const SHOTGUN_PRICE := 400
const AMMO_PRICE := 40

var m: Node3D
var points: Array = []        # {"pos","r","id"}
var police: Array = []
var cops: Array = []
var traffic: Array = []
var heli: Heli3D
var news_heli: Heli3D
var heli_gone_t := 0.0
var cop_spawn_t := 0.0
var shot_cd := 0.0
var peds: Array = []          # {"n": Npc3D, "t": float}
var heat := 0.0
var stars := 0
var clear_t := 0.0
var spawn_t := 0.0
var bust_t := 0.0
var ram_cd := 0.0
var crime_cd := 0.0
var price := 12.0
var trend := 0.0
var price_t := 3.0
var news_t := 40.0
var board: Label3D
var sport_car: Car3D
var uaz_car: Car3D
var yacht_node: Node3D
var beers := 0
var in_shop := ""
var shop_ret := Vector3.ZERO
const SHOP_OFF := {"bar": Vector3(600, 0, 600), "guns": Vector3(640, 0, 600)}


func _ready() -> void:
	m = get_parent()
	_build()


# ---------------- постройка ----------------

func _bx(parent: Node3D, size: Vector3, pos: Vector3, col: Color, solid: bool = true) -> void:
	MeshKit.inst([MeshKit.box(size, pos, col)], parent)
	if solid:
		MeshKit.static_box(parent, size, pos)


func _windows(parent: Node3D, cols: int, rows: int, w: float, h: float, base: Vector3, sx: float, sy: float, col: Color) -> void:
	var parts: Array = []
	for r in rows:
		for c in cols:
			if (r * 7 + c * 3) % 5 == 0:
				continue
			parts.append(MeshKit.box(Vector3(w, h, 0.08), base + Vector3(c * sx, r * sy, 0)))
	MeshKit.glow_inst(parts, col, parent, 1.4)


func _building(pos: Vector3, size: Vector3, col: Color, roof: Color, title: String, title_col: Color, windows: bool = true) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	m.world.add_child(n)
	_bx(n, size, Vector3(0, size.y / 2.0, 0), col)
	_bx(n, Vector3(size.x + 0.6, 0.4, size.z + 0.6), Vector3(0, size.y + 0.2, 0), roof, false)
	var fz := size.z / 2.0 + 0.05
	if windows:
		_windows(n, int(size.x / 2.6), 1, 1.4, 1.3, Vector3(-size.x / 2.0 + 1.6, 2.2, fz), 2.6, 0.0, Color("ffe9a0"))
	MeshKit.label(title, Vector3(0, size.y - 0.7, fz + 0.1), title_col, 52, 0.011, false, n)
	return n


func _build() -> void:
	var w: Node3D = m.world
	# дороги
	MeshKit.inst([MeshKit.box(Vector3(98, 0.06, 7.0), Vector3(48, 0.03, 0), Color("2c2f36"))], w, C - Vector3(48, 0, 0))
	MeshKit.inst([MeshKit.box(Vector3(5.0, 0.06, 20.0), Vector3(0, 0.03, 0), Color("2c2f36"))], w, Vector3(0, 0, 66))
	var lines: Array = []
	for i in 22:
		lines.append(MeshKit.box(Vector3(2.4, 0.02, 0.18), Vector3(2.0 + i * 4.4, 0.075, 0), Color("e8e2b0")))
	MeshKit.inst(lines, w, C - Vector3(48, 0, 0))
	# тротуар
	MeshKit.inst([MeshKit.box(Vector3(98, 0.08, 2.2), Vector3(48, 0.04, -4.6), Color("8f9199")),
		MeshKit.box(Vector3(98, 0.08, 2.2), Vector3(48, 0.04, 4.6), Color("8f9199"))], w, C - Vector3(48, 0, 0))
	# башня
	var tw := Node3D.new()
	tw.position = C + Vector3(-6, 0, -28)
	w.add_child(tw)
	_bx(tw, Vector3(14, 40, 12), Vector3(0, 20, 0), Color("1d3550"))
	_bx(tw, Vector3(14.8, 0.8, 12.8), Vector3(0, 40.4, 0), Color("0e1c2e"), false)
	_windows(tw, 5, 12, 1.6, 1.8, Vector3(-5.6, 2.6, 6.06), 2.8, 3.2, Color("9fd8ff"))
	MeshKit.label("ВОЛК-ТАУЭР", Vector3(0, 36.5, 6.15), Color("ffe08a"), 70, 0.02, false, tw)
	MeshKit.label("Инвестиции в лес", Vector3(0, 34.2, 6.15), Color("cfe8ff"), 40, 0.015, false, tw)
	# биржа дров
	var ex := _building(C + Vector3(8, 0, -9), Vector3(8, 4.2, 5), Color("d9d2bd"), Color("3a3a44"), "БИРЖА ДРОВ", Color("1a3a1a"), false)
	board = MeshKit.label("", Vector3(0, 1.9, 2.62), Color("39ff7a"), 60, 0.012, false, ex)
	MeshKit.inst([MeshKit.box(Vector3(5.2, 1.1, 0.1), Vector3(0, 2.0, 2.52), Color("101418"))], ex)
	points.append({"pos": C + Vector3(8, 0, -5.0), "r": 3.2, "id": "sell"})
	# пивная
	var bar := _building(C + Vector3(-22, 0, -10), Vector3(11, 4.5, 8), Color("7a4a2a"), Color("3a2412"), "ПИВНАЯ У ЭДИКА", Color("ffd23a"))
	for tx in [-2.5, 2.5]:
		var t: Array = [MeshKit.cyl(0.6, 0.6, 0.06, Vector3(tx, 0.9, 6.4), Color("5a3a22"), Vector3.ZERO, 10),
			MeshKit.cyl(0.06, 0.06, 0.9, Vector3(tx, 0.45, 6.4), Color("2a2a2a"), Vector3.ZERO, 6),
			MeshKit.cyl(0.11, 0.11, 0.28, Vector3(tx - 0.2, 1.08, 6.4), Color("e8b020"), Vector3.ZERO, 8),
			MeshKit.cyl(0.11, 0.11, 0.1, Vector3(tx - 0.2, 1.26, 6.4), Color("f6f2e0"), Vector3.ZERO, 8)]
		MeshKit.inst(t, bar)
	MeshKit.inst([MeshKit.box(Vector3(1.8, 2.5, 0.12), Vector3.ZERO, Color("c9a35a"))], bar, Vector3(0, 1.25, 4.08))
	var barman := Npc3D.new()
	barman.position = C + Vector3(-22, 0, -4.5)
	barman.rotation.y = 0.0
	w.add_child(barman)
	barman.setup("Эдик", {"shirt": Color("f2f2f2"), "pants": Color("2a2a2a"), "hat": "none", "beard": true,
		"beard_col": Color("3a2a1a"), "skin": Color("e0b890")})
	points.append({"pos": C + Vector3(-22, 0, -3.6), "r": 2.6, "id": "enter_bar"})
	# автосалон
	var dl := _building(C + Vector3(26, 0, -10), Vector3(11, 4.2, 8), Color("e8e8f0"), Color("20242c"), "АВТОСАЛОН «ПОНТЫ»", Color("b01a35"))
	points.append({"pos": C + Vector3(20, 0, -3.8), "r": 4.0, "id": "dealer"})
	dl.name = "Dealer"
	sport_car = Car3D.new()
	sport_car.kind = "sport"
	sport_car.position = C + Vector3(23.5, 0, -5.0)
	sport_car.rotation.y = deg_to_rad(90)
	w.add_child(sport_car)
	uaz_car = Car3D.new()
	uaz_car.kind = "uaz"
	uaz_car.position = Vector3(-10, 0, -24)
	uaz_car.rotation.y = deg_to_rad(-30)
	w.add_child(uaz_car)
	m.cars.append(sport_car)
	m.cars.append(uaz_car)
	m.spring.add_excluded_object(sport_car.get_rid())
	m.spring.add_excluded_object(uaz_car.get_rid())
	# оружейный магазин
	var gb := _building(C + Vector3(-42, 0, -10), Vector3(10, 4.2, 8), Color("4a4f3a"), Color("22261a"), "ОРУЖЕЙНЫЙ «ВОЛК И ПАТРОН»", Color("ffd23a"))
	MeshKit.inst([MeshKit.box(Vector3(1.8, 2.5, 0.12), Vector3.ZERO, Color("c9a35a"))], gb, Vector3(0, 1.25, 4.08))
	points.append({"pos": C + Vector3(-42, 0, -3.6), "r": 2.6, "id": "enter_guns"})
	_build_shops()
	# милиция
	var st := _building(C + Vector3(0, 0, 14), Vector3(14, 4.6, 8), Color("c9d4e6"), Color("20304a"), "МИЛИЦИЯ", Color("1a3a8a"))
	st.rotation.y = PI
	for sx in [-5.0, 5.0]:
		var pc := Car3D.new()
		pc.kind = "police"
		pc.position = C + Vector3(sx, 0, 8.2)
		pc.rotation.y = 0.0
		w.add_child(pc)
	# фонари
	var lamps: Array = []
	for i in 9:
		var x := 8.0 + i * 11.0
		lamps.append(MeshKit.cyl(0.07, 0.09, 4.6, Vector3(x, 2.3, 4.2), Color("2a2a30"), Vector3.ZERO, 6))
	MeshKit.inst(lamps, w, C - Vector3(48, 0, 0))
	var bulbs: Array = []
	for i in 9:
		bulbs.append(MeshKit.sph(0.22, Vector3(8.0 + i * 11.0, 4.7, 4.2), Color("fff0c0"), Vector3.ONE, 6))
	MeshKit.glow_inst(bulbs, Color("fff0c0"), w, 1.6).position = C - Vector3(48, 0, 0)
	# указатели
	var s1 := WorldBuilder.sign_post(Loc.t("ГОРОД >"))
	s1.position = Vector3(-4, 0, 36)
	s1.rotation.y = deg_to_rad(180)
	w.add_child(s1)
	# яхта
	yacht_node = Node3D.new()
	yacht_node.position = Vector3(84, 0.25, 24)
	yacht_node.rotation.y = deg_to_rad(20)
	w.add_child(yacht_node)
	var yp: Array = [MeshKit.box(Vector3(3.6, 1.0, 11), Vector3(0, 0.5, 0), Color("f4f4f8")),
		MeshKit.box(Vector3(3.2, 0.2, 10.4), Vector3(0, 1.1, 0), Color("c9a46a")),
		MeshKit.box(Vector3(2.6, 1.3, 4.0), Vector3(0, 1.85, 1.2), Color("f4f4f8")),
		MeshKit.box(Vector3(2.7, 0.5, 3.6), Vector3(0, 2.1, 1.2), Color("1d2a30")),
		MeshKit.box(Vector3(3.4, 0.14, 0.2), Vector3(0, 0.95, -5.4), Color("1d4a8a")),
		MeshKit.cyl(0.08, 0.08, 3.2, Vector3(0, 3.6, 1.2), Color("c9ced6"), Vector3.ZERO, 6)]
	MeshKit.inst(yp, yacht_node)
	MeshKit.label("WOLF OF DACHA", Vector3(1.8, 1.0, 1.0), Color("1d4a8a"), 40, 0.01, false, yacht_node).rotation.y = PI / 2
	yacht_node.visible = Game.yacht
	points.append({"pos": Vector3(72, 0, 22.5), "r": 3.6, "id": "yacht"})
	var ds := Node3D.new()
	ds.position = Vector3(72, 0, 22.5)
	w.add_child(ds)
	MeshKit.inst([MeshKit.box(Vector3(5, 0.2, 2.4), Vector3(-2.4, 0.1, 0), Color("8a6a44"))], ds)
	MeshKit.label("ПРИСТАНЬ: ЯХТА $%d" % YACHT_PRICE, Vector3(0, 2.4, 0), Color("ffe08a"), 42, 0.01, true, ds)
	# прохожие-брокеры
	var suits := [Color("2a2f3a"), Color("3a3a44"), Color("1d2a4a"), Color("4a2a2a"), Color("2a3a2a"), Color("3a2a4a")]
	for i in 14:
		var x0 := C.x - 40.0 + i * 6.2
		var n := Npc3D.new()
		n.position = Vector3(x0, 0, C.z + (-4.6 if i % 2 == 0 else 4.6))
		w.add_child(n)
		n.setup("Прохожий", {"shirt": suits[i % 6], "pants": suits[i % 6], "hat": "none", "skin": [Color("e7b48a"), Color("c68a5a"), Color("f0c8a0")][i % 3]}, false)
		n.walk_speed = 1.3 + 0.15 * (i % 3)
		n.route = [n.position, n.position + Vector3(18 if i % 2 == 0 else -18, 0, 0)]
		peds.append({"n": n, "t": 0.0, "hp": 100.0, "dead": 0.0, "start": n.position})
	_update_board()
	_build_traffic()
	news_heli = Heli3D.new()
	news_heli.kind = "news"
	news_heli.orbit_c = C
	news_heli.position = C + Vector3(40, 38, 0)
	w.add_child(news_heli)


func _lane_pts() -> Array:
	var z0 := C.z
	var x0 := C.x - 46.0
	var x1 := C.x + 46.0
	return [Vector3(x0 + 4, 0, z0 + 1.8), Vector3(x1 - 6, 0, z0 + 1.8),
		Vector3(x1 + 1, 0, z0 + 1.8), Vector3(x1 + 6, 0, z0), Vector3(x1 + 1, 0, z0 - 1.8),
		Vector3(x1 - 6, 0, z0 - 1.8), Vector3(x0 + 4, 0, z0 - 1.8),
		Vector3(x0 - 1, 0, z0 - 1.8), Vector3(x0 - 6, 0, z0), Vector3(x0 - 1, 0, z0 + 1.8)]


func _build_traffic() -> void:
	var lp := _lane_pts()
	var cols := [Color("c43a3a"), Color("3a6ac4"), Color("e8e8e8"), Color("3a3a3a"), Color("d8a02a"), Color("5a9a5a"), Color("8a4ac4")]
	for i in 7:
		var c := Car3D.new()
		c.kind = "passat"
		c.body_col = cols[i]
		c.ai = true
		var wp := 0 if i % 2 == 0 else 5
		var a: Vector3 = lp[wp % lp.size()]
		var b: Vector3 = lp[(wp + 1) % lp.size()]
		c.set_meta("wp", (wp + 1) % lp.size())
		c.max_fwd = 11.0
		m.world.add_child(c)
		c.global_position = a.lerp(b, 0.1 + 0.12 * i) + Vector3(0, 0.05, 0)
		var dd := b - a
		c.rotation.y = atan2(-dd.x, -dd.z)
		traffic.append(c)


func _traffic(delta: float) -> void:
	var lp := _lane_pts()
	var pp: Vector3 = m.car.global_position if m.mode == "car" else m.player.global_position
	for c in traffic:
		var car := c as Car3D
		var wp: int = int(car.get_meta("wp"))
		var tg: Vector3 = lp[wp]
		var to := tg - car.global_position
		to.y = 0.0
		if to.length() < (2.6 if wp in [3, 8] else 3.6):
			wp = (wp + 1) % lp.size()
			car.set_meta("wp", wp)
			tg = lp[wp]
			to = tg - car.global_position
			to.y = 0.0
		var fwd := -car.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var ang := fwd.signed_angle_to(to.normalized(), Vector3.UP)
		var thr := 0.62 if absf(ang) < 0.4 else 0.35
		if wp in [2, 3, 4, 7, 8, 9]:
			thr = 0.3
		# тормозим, если впереди кто-то
		var others: Array = traffic.duplicate()
		others.append(m.car)
		var blockers: Array = []
		for o in others:
			if o != c:
				blockers.append((o as Node3D).global_position)
		blockers.append(pp)
		var wait_t: float = float(car.get_meta("wait", 0.0))
		var blocked := false
		var right := fwd.cross(Vector3.UP)
		for bpos in blockers:
			var rel: Vector3 = (bpos as Vector3) - car.global_position
			rel.y = 0.0
			var ahead := rel.dot(fwd)
			if ahead > 0.5 and ahead < 8.0 and absf(rel.dot(right)) < 2.3:
				blocked = true
		if blocked and wait_t < 4.0:
			thr = 0.0
			wait_t += delta
		else:
			wait_t = maxf(0.0, wait_t - delta * 2.0) if not blocked else wait_t + delta
			if wait_t > 7.0:
				wait_t = 0.0
		car.set_meta("wait", wait_t)
		car.drive(thr, -clampf(ang * 2.2, -1.0, 1.0), delta)
		# сбил пешехода или игрока
		if absf(car.speed) > 4.0:
			if m.mode != "car" and car.global_position.distance_to(m.player.global_position) < 2.3 and m.player.invuln <= 0.0:
				m.player.hurt(15.0, car.global_position, 9.0, 5.0, 1.3)
			for pd in peds:
				if float(pd["dead"]) <= 0.0 and (pd["n"] as Node3D).global_position.distance_to(car.global_position) < 2.2:
					_damage(pd, 100.0, car.global_position, false)


# ---------------- заходим в здания ----------------

func _build_shops() -> void:
	for k in ["bar", "guns"]:
		var off: Vector3 = SHOP_OFF[k]
		var root := Node3D.new()
		root.position = off
		m.world.add_child(root)
		var bar: bool = k == "bar"
		var wall := Color("8a5c36") if bar else Color("6a7358")
		var flo := Color("3a2616") if bar else Color("2a2d24")
		_bx(root, Vector3(12, 0.4, 9), Vector3(0, -0.2, 0), flo)
		_bx(root, Vector3(12.6, 4, 0.4), Vector3(0, 2, -4.7), wall)
		_bx(root, Vector3(0.4, 4, 9), Vector3(-6.2, 2, 0), wall)
		_bx(root, Vector3(0.4, 4, 9), Vector3(6.2, 2, 0), wall)
		_bx(root, Vector3(12.6, 4, 0.4), Vector3(0, 2, 4.7), wall)
		MeshKit.inst([MeshKit.box(Vector3(12.8, 0.3, 9.8), Vector3.ZERO, Color("2a1a10"))], root, Vector3(0, 4.15, 0))
		# дверь (светлая полоса) и табличка
		MeshKit.inst([MeshKit.box(Vector3(1.6, 2.4, 0.1), Vector3.ZERO, Color("c9a35a"))], root, Vector3(0, 1.2, 4.45))
		MeshKit.label("ВЫХОД", Vector3(0, 2.8, 4.45), Color("7aff9a"), 44, 0.012, false, root)
		# прилавок
		_bx(root, Vector3(7, 1.1, 0.9), Vector3(0, 0.55, -1.2), Color("8a5a2e") if bar else Color("3a3f34"))
		MeshKit.inst([MeshKit.box(Vector3(7.2, 0.12, 1.1), Vector3.ZERO, Color("c79a5a") if bar else Color("5a6048"))], root, Vector3(0, 1.15, -1.2))
		var npc := Npc3D.new()
		npc.position = off + Vector3(0, 0, -2.5)
		m.world.add_child(npc)
		if bar:
			npc.setup("Эдик", {"shirt": Color("f2f2f2"), "pants": Color("2a2a2a"), "hat": "none", "beard": true,
				"beard_col": Color("3a2a1a"), "skin": Color("e0b890")})
			MeshKit.label("ПИВНАЯ У ЭДИКА", Vector3(0, 3.3, -4.45), Color("ffd23a"), 60, 0.014, false, root)
			# полки с бутылками
			for i in 12:
				var bx := -5.0 + i * 0.9
				MeshKit.inst([MeshKit.cyl(0.1, 0.1, 0.4, Vector3.ZERO, [Color("2f7a3a"), Color("8a4a1a"), Color("d0c070")][i % 3], Vector3.ZERO, 8)], root, Vector3(bx, 2.2 if i % 2 == 0 else 1.7, -4.4))
			# столики и стулья
			for tp in [Vector3(-3.6, 0, 1.4), Vector3(3.6, 0, 1.4), Vector3(-3.6, 0, 3.2), Vector3(3.6, 0, 3.2)]:
				MeshKit.inst([MeshKit.cyl(0.55, 0.55, 0.06, Vector3(0, 0.85, 0), Color("5a3a22"), Vector3.ZERO, 10),
					MeshKit.cyl(0.07, 0.07, 0.85, Vector3(0, 0.42, 0), Color("2a2a2a"), Vector3.ZERO, 6),
					MeshKit.cyl(0.1, 0.1, 0.25, Vector3(0.15, 1.0, 0), Color("e8b020"), Vector3.ZERO, 8)], root, tp)
			points.append({"pos": off + Vector3(0, 0, -0.1), "r": 3.4, "id": "beer"})
		else:
			npc.setup("Макс", {"shirt": Color("5a6a3a"), "pants": Color("2a2a22"), "hat": "none", "beard": false,
				"skin": Color("d8b090")})
			MeshKit.label("ВОЛК И ПАТРОН", Vector3(0, 3.3, -4.45), Color("ffd23a"), 60, 0.014, false, root)
			# стенды с оружием
			for i in 6:
				var gx := -4.8 + i * 1.9
				MeshKit.inst([MeshKit.box(Vector3(1.2, 0.12, 0.35), Vector3.ZERO, Color("2a2a2a")),
					MeshKit.box(Vector3(1.0, 0.1, 0.12), Vector3(0, 0.12, 0), Color("1a1a1a")),
					MeshKit.box(Vector3(0.3, 0.2, 0.1), Vector3(-0.35, 0.0, 0), Color("5a3a1a"))], root, Vector3(gx, 1.8 + (i % 2) * 0.6, -4.4))
			_bx(root, Vector3(1.2, 1.0, 1.2), Vector3(-4.2, 0.5, 2.8), Color("3a3f34"))
			_bx(root, Vector3(1.2, 1.0, 1.2), Vector3(4.2, 0.5, 2.8), Color("3a3f34"))
			points.append({"pos": off + Vector3(0, 0, -0.1), "r": 3.4, "id": "guns"})
		points.append({"pos": off + Vector3(0, 0, 3.7), "r": 1.9, "id": "exit_shop"})
		for lx in [-3.5, 3.5]:
			var l := OmniLight3D.new()
			l.position = Vector3(lx, 3.2, 0.5)
			l.omni_range = 14.0
			l.light_energy = 2.8
			l.light_color = Color("ffd9a0")
			root.add_child(l)


func _enter_shop(k: String) -> void:
	var off: Vector3 = SHOP_OFF[k]
	shop_ret = m.player.global_position
	m._transition(func():
		in_shop = k
		m.player.velocity = Vector3.ZERO
		m.player.global_position = off + Vector3(0, 0.05, 2.6)
		m.player.face = 0.0
		m.yaw = 0.0
		m.pitch = 0.4
		Sfx.play("coin", 0.8))


func _exit_shop() -> void:
	var back := shop_ret
	m._transition(func():
		in_shop = ""
		m.player.velocity = Vector3.ZERO
		m.player.global_position = back
		m.pitch = 0.38)


# ---------------- интерфейс игрока ----------------

func near_label(pp: Vector3) -> String:
	for p in points:
		var pos: Vector3 = p["pos"]
		if Vector2(pp.x - pos.x, pp.z - pos.z).length() < float(p["r"]):
			match String(p["id"]):
				"sell":
					return "Продать брёвна"
				"enter_bar":
					return "Войти в пивную"
				"enter_guns":
					return "Войти в оружейный"
				"exit_shop":
					return "Выйти на улицу"
				"beer":
					return "Пиво $%d" % BEER_PRICE
				"dealer":
					return "Спорткар (куплен)" if Game.owned_sport else "Купить спорткар $%d" % SPORT_PRICE
				"yacht":
					return "Яхта (куплена)" if Game.yacht else "Купить яхту $%d" % YACHT_PRICE
				"guns":
					if not Game.has_pistol:
						return "Пистолет $%d" % PISTOL_PRICE
					if not Game.has_shotgun:
						return "Дробовик $%d" % SHOTGUN_PRICE
					return "Патроны $%d" % AMMO_PRICE
				_:
					if String(p["id"]).begins_with("m1_") and m.mission != null:
						var ml: String = m.mission.label(String(p["id"]))
						if ml != "":
							return ml
	return ""


func interact(pp: Vector3) -> void:
	for p in points:
		var pos: Vector3 = p["pos"]
		if Vector2(pp.x - pos.x, pp.z - pos.z).length() < float(p["r"]):
			match String(p["id"]):
				"sell":
					_sell()
				"enter_bar":
					_enter_shop("bar")
				"enter_guns":
					_enter_shop("guns")
				"exit_shop":
					_exit_shop()
				"beer":
					_beer()
				"dealer":
					_dealer()
				"yacht":
					_yacht()
				"guns":
					_guns()
				_:
					if String(p["id"]).begins_with("m1_") and m.mission != null:
						if m.mission.label(String(p["id"])) == "":
							continue
						m.mission.act(String(p["id"]))
			return


func _toast(t: String, c: Color = Color("ffd23a")) -> void:
	m.ui.toast(t, c)


func _dlg(who: String, lines: Array) -> void:
	m.mode = "dialog"
	m.ui.open_dialog(who, lines, func() -> void: m.mode = "play")


func _sell() -> void:
	var extra: int = maxi(0, Game.wood - KEEP_LOGS)
	var fish: int = Game.fish
	if extra <= 0 and fish <= 0:
		_dlg("Брокер Игорь", ["Продай мне это бревно! ...У тебя их ровно %d. Десять я оставляю тебе на стройку, дружище." % Game.wood, "Руби ещё — сегодня дровами торгуют по $%d." % int(price)])
		return
	var total := int(round(extra * price)) + fish * 8
	Game.wood -= extra
	Game.fish = 0
	Game.cash += total
	Game.changed.emit()
	Sfx.play("cheer", 1.2)
	_toast("Продал %d брёв по $%d%s = +$%d" % [extra, int(price), (" и рыбу" if fish > 0 else ""), total], Color("8aff9a"))
	if total >= 150:
		rain(m.player.global_position)


func _beer() -> void:
	if m.drunk >= 5.0:
		_dlg("Эдик", ["Хватит, Михалыч! Ты уже ноль-пять от пола не отличаешь."])
		return
	if Game.cash < BEER_PRICE:
		_dlg("Эдик", ["Пиво $%d. А у тебя... %d. Продай брёвна на Бирже, брокер!" % [BEER_PRICE, Game.cash]])
		return
	Game.cash -= BEER_PRICE
	beers += 1
	m.drunk = minf(5.0, m.drunk + 1.0)
	Sfx.play("cheer", 0.9)
	_toast("Выпил пиво «Дачное». Голова кругом!", Color("ffe08a"))
	if beers % 4 == 0:
		_toast("Эдик: четвёртая за счёт заведения!", Color("ff9aff"))
		rain(m.player.global_position)


func _dealer() -> void:
	if Game.owned_sport:
		_toast("Спорткар уже твой. Он стоит рядом.", Color("9aff9a"))
		return
	if Game.cash < SPORT_PRICE:
		_dlg("Продавец Лёха", ["Красотка, а? Жёлтая, как твоя зарплата. Стоит $%d." % SPORT_PRICE, "У тебя только $%d. Торгуй дровами, брокер. Или... можешь угнать, но тогда прибежит милиция." % Game.cash])
		return
	Game.cash -= SPORT_PRICE
	Game.owned_sport = true
	Game.changed.emit()
	Sfx.play("cheer", 1.3)
	_toast("Ты купил спорткар! Ключи в зажигании.", Color("8aff9a"))
	rain(m.player.global_position)


func _guns() -> void:
	if not Game.has_pistol:
		if Game.cash < PISTOL_PRICE:
			_dlg("Продавец Макс", ["Пистолет — $%d. А у тебя $%d. Приходи с деньгами, дачник." % [PISTOL_PRICE, Game.cash]])
			return
		Game.cash -= PISTOL_PRICE
		Game.has_pistol = true
		Game.ammo_p += 24
		_toast("Куплен пистолет и 24 патрона. Кнопка «Оружие» — переключить.", Color("8aff9a"))
	elif not Game.has_shotgun:
		if Game.cash < SHOTGUN_PRICE:
			_dlg("Продавец Макс", ["Дробовик — $%d. У тебя $%d." % [SHOTGUN_PRICE, Game.cash]])
			return
		Game.cash -= SHOTGUN_PRICE
		Game.has_shotgun = true
		Game.ammo_s += 8
		_toast("Куплен дробовик и 8 патронов.", Color("8aff9a"))
	else:
		if Game.cash < AMMO_PRICE:
			_toast("Патроны стоят $%d." % AMMO_PRICE, Color("ff9a9a"))
			return
		Game.cash -= AMMO_PRICE
		Game.ammo_p += 24
		Game.ammo_s += 8
		_toast("+24 патрона к пистолету, +8 к дробовику.", Color("8aff9a"))
	Game.changed.emit()
	Sfx.play("coin", 1.0)


func _yacht() -> void:
	if Game.yacht:
		_toast("Яхта твоя. Ты настоящий волк с дачи.", Color("9aff9a"))
		return
	if Game.cash < YACHT_PRICE:
		_toast("Яхта стоит $%d. Тебе не хватает $%d." % [YACHT_PRICE, YACHT_PRICE - Game.cash], Color("ff9a9a"))
		return
	Game.cash -= YACHT_PRICE
	Game.yacht = true
	yacht_node.visible = true
	Game.changed.emit()
	Sfx.play("cheer", 0.8)
	_toast("ЯХТА КУПЛЕНА! Теперь ты настоящий волк с Дачи-стрит.", Color("ffe08a"))
	rain(m.player.global_position)
	Game.save()


func rain(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 6.0, 0)
	p.emitting = true
	p.one_shot = true
	p.amount = 90
	p.lifetime = 3.2
	p.explosiveness = 0.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(4, 0.2, 4)
	p.direction = Vector3(0, -1, 0)
	p.spread = 20.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -3.0, 0)
	p.angle_max = 360.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.38, 0.02, 0.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("5ad06a")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	p.mesh = bm
	m.add_child(p)
	get_tree().create_timer(4.5).timeout.connect(p.queue_free)


# ---------------- Биржа ----------------

func _update_board() -> void:
	if board != null:
		board.text = "ДРОВА  $%d  %s" % [int(price), "▲" if trend >= 0.0 else "▼"]
		board.modulate = Color("39ff7a") if trend >= 0.0 else Color("ff5a5a")


func _market(delta: float) -> void:
	price_t -= delta
	if price_t <= 0.0:
		price_t = 5.0
		price = clampf(price + randf_range(-2.5, 2.5) + trend, 5.0, 45.0)
		_update_board()
	news_t -= delta
	if news_t <= 0.0:
		news_t = randf_range(50.0, 90.0)
		if randf() < 0.5:
			trend = 1.6
			_toast("БИРЖА: бревно в цене! Спрос на дрова растёт!", Color("8aff9a"))
		else:
			trend = -1.6
			_toast("БИРЖА: паника! Дрова дешевеют!", Color("ff8a8a"))
		get_tree().create_timer(25.0).timeout.connect(func() -> void: trend = 0.0)


# ---------------- розыск и милиция ----------------

func add_heat(h: float, why: String) -> void:
	if crime_cd > 0.0 and h < 2.0:
		return
	crime_cd = 1.2
	var before := stars
	heat = minf(5.0, heat + h)
	stars = ceili(heat - 0.001)
	clear_t = 0.0
	if stars > before:
		_toast("%s  РОЗЫСК %s" % [why, "★".repeat(stars)], Color("ff6a6a"))
		Sfx.play("howl", 1.5)


func _heli_logic(delta: float) -> void:
	var inside: bool = m.in_club or m.in_house != "" or in_shop != "" or m.mode == "dead"
	if stars >= 4 and heli == null and not inside:
		heli = Heli3D.new()
		heli.kind = "police"
		heli.position = C + Vector3(0, 24, 18)
		m.world.add_child(heli)
		_toast("Над головой полицейский вертолёт!", Color("ff6a6a"))
		Sfx.play("siren", 1.0)
	if heli == null:
		return
	if is_instance_valid(heli) == false:
		heli = null
		return
	if stars < 4 and not heli.dying:
		heli_gone_t += delta
		if heli_gone_t > 6.0:
			heli.queue_free()
			heli = null
			heli_gone_t = 0.0
			return
	else:
		heli_gone_t = 0.0
	var tgt: Vector3 = m.car.global_position if m.mode == "car" else m.player.global_position
	var night: bool = m.dn != null and m.dn.darkness > 0.2
	if heli.think(delta, tgt, night):
		var from := heli.global_position + Vector3(0, -0.6, -1.5)
		var chest := tgt + Vector3(0, 1.1, 0)
		var hit := randf() < (0.1 if m.mode == "car" else 0.2)
		var endp := chest if hit else chest + Vector3(randf_range(-2.5, 2.5), randf_range(-0.5, 0.5), randf_range(-2.5, 2.5))
		m.weapons.tracer(from, endp, Color("ff9a6a"))
		Sfx.play("shot", 0.8)
		if hit and m.mode != "car":
			m.player.invuln = 0.0
			m.player.hurt(4.0, heli.global_position, 2.0)
		elif hit:
			Game.hp = maxf(1.0, Game.hp - 2.0)
	if heli.dying and heli.global_position.y <= 0.8:
		_explosion(heli.global_position)
		heli.queue_free()
		heli = null


func heli_hurt(h: Heli3D, dmg: float) -> void:
	if h.hurt(dmg):
		Game.cash += 100
		Game.changed.emit()
		_toast("Сбил полицейский вертолёт! +$100", Color("ff8a8a"))
		add_heat(2.0, "ВЕРТОЛЁТ СБИТ!")


func _explosion(pos: Vector3) -> void:
	Sfx.play("fell", 0.45)
	Sfx.play("howl", 1.6)
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.8, 0)
	p.emitting = true
	p.one_shot = true
	p.amount = 50
	p.lifetime = 1.1
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 12.0
	p.gravity = Vector3(0, -9.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.56
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("ff8a1e")
	mat.emission_enabled = true
	mat.emission = Color("ff5a0a")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.mesh = mesh
	m.add_child(p)
	var l := OmniLight3D.new()
	l.light_color = Color("ff9a3a")
	l.light_energy = 7.0
	l.omni_range = 18.0
	l.position = pos + Vector3(0, 1.5, 0)
	m.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.8)
	tw.tween_callback(l.queue_free)
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func on_shot() -> void:
	var near: bool = m.player.global_position.distance_to(C) < 60.0
	if not near:
		for pd in peds:
			if (pd["n"] as Node3D).global_position.distance_to(m.player.global_position) < 25.0:
				near = true
				break
	if near:
		add_heat(0.7, "Стрельба!")


func cop_hurt(c: Cop3D, dmg: float, from: Vector3) -> void:
	blood(c.global_position + Vector3(0, 1.2, 0), false)
	if c.hurt(dmg, from):
		blood(c.global_position + Vector3(0, 0.3, 0), true)
		Game.cash += 30
		var extra := ""
		if Game.has_pistol:
			Game.ammo_p += 12
			extra = " +12 патр."
		Game.changed.emit()
		_toast("Убил милиционера: +$30%s" % extra, Color("ff8a8a"))
		add_heat(2.0, "УБИЙСТВО МИЛИЦИОНЕРА!")
		get_tree().create_timer(18.0).timeout.connect(func() -> void:
			if is_instance_valid(c):
				c.queue_free())
	else:
		add_heat(1.0, "Нападение на милицию!")


func clear_wanted(quiet: bool = false) -> void:
	in_shop = ""
	heat = 0.0
	stars = 0
	bust_t = 0.0
	for p in police:
		if is_instance_valid(p):
			(p as Node).queue_free()
	police.clear()
	for c in cops:
		if is_instance_valid(c):
			(c as Node).queue_free()
	cops.clear()
	if heli != null and is_instance_valid(heli):
		heli.queue_free()
	heli = null
	if not quiet:
		_toast("Розыск снят. Дыши свободно.", Color("9aff9a"))


func on_enter_car(c: Car3D) -> void:
	if c == sport_car and not Game.owned_sport:
		add_heat(2.0, "УГОН!")


func hit_ped(ppos: Vector3, fwd: Vector3, dmg: float = 40.0, cop_dmg: float = 45.0) -> bool:
	for pd in peds:
		var n: Npc3D = pd["n"]
		if float(pd["dead"]) > 0.0:
			continue
		var d := n.global_position - ppos
		d.y = 0.0
		if d.length() < 2.4 and d.normalized().dot(fwd) > 0.0:
			_damage(pd, dmg, ppos)
			return true
	for c in cops:
		if not is_instance_valid(c) or (c as Cop3D).dying:
			continue
		var d2 := (c as Node3D).global_position - ppos
		d2.y = 0.0
		if d2.length() < 2.4 and d2.normalized().dot(fwd) > 0.0:
			cop_hurt(c, cop_dmg, ppos)
			return true
	return false


## Урон прохожему: кровь, нокдаун, смерть, добыча из кармана.
func _damage(pd: Dictionary, dmg: float, from: Vector3, crime: bool = true) -> void:
	var n: Npc3D = pd["n"]
	pd["hp"] = float(pd["hp"]) - dmg
	Sfx.play("hit", 0.8)
	blood(n.global_position + Vector3(0, 1.2, 0), false)
	if float(pd["hp"]) <= 0.0:
		pd["dead"] = 25.0
		n.hum.rotation.z = 1.45
		n.set_process(false)
		blood(n.global_position + Vector3(0, 0.3, 0), true)
		var loot := randi_range(20, 60)
		if crime:
			Game.cash += loot
			Game.changed.emit()
			_toast("Убил прохожего. Из кармана +$%d" % loot, Color("ff8a8a"))
			add_heat(2.0, "УБИЙСТВО!")
	else:
		pd["t"] = 2.5
		n.hum.rotation.z = 1.2
		n.set_process(false)
		if crime:
			add_heat(1.0, "Нападение на прохожего!")


var pools: Array = []


func blood(pos: Vector3, big: bool) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.emitting = true
	p.one_shot = true
	p.amount = 34 if big else 14
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 80.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0 if big else 4.0
	p.gravity = Vector3(0, -12.0, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	sm.radial_segments = 6
	sm.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("a10f14")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mat
	p.mesh = sm
	m.add_child(p)
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)
	if big:
		var d := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.95
		cm.bottom_radius = 0.95
		cm.height = 0.01
		cm.radial_segments = 12
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color("7a0c10")
		dm.roughness = 0.4
		cm.material = dm
		d.mesh = cm
		d.position = Vector3(pos.x, 0.11, pos.z)
		m.add_child(d)
		pools.append(d)
		if pools.size() > 24:
			var old: Node = pools.pop_front()
			if is_instance_valid(old):
				old.queue_free()
		get_tree().create_timer(90.0).timeout.connect(func() -> void:
			if is_instance_valid(d):
				d.queue_free())


func car_update(c: Car3D, delta: float) -> void:
	ram_cd = maxf(0.0, ram_cd - delta)
	if absf(c.speed) < 5.0:
		return
	for pd in peds:
		var n: Npc3D = pd["n"]
		if float(pd["dead"]) <= 0.0 and n.global_position.distance_to(c.global_position) < 2.6:
			_damage(pd, 100.0 if absf(c.speed) > 11.0 else 55.0, c.global_position)
	for p in police:
		if is_instance_valid(p) and (p as Node3D).global_position.distance_to(c.global_position) < 3.4 and ram_cd <= 0.0 and absf(c.speed) > 8.0:
			ram_cd = 3.0
			add_heat(1.0, "Таран милиции!")


func _process(delta: float) -> void:
	crime_cd = maxf(0.0, crime_cd - delta)
	_market(delta)
	for pd in peds:
		var n: Npc3D = pd["n"]
		if float(pd["dead"]) > 0.0:
			pd["dead"] = float(pd["dead"]) - delta
			if float(pd["dead"]) <= 0.0:
				pd["hp"] = 100.0
				pd["t"] = 0.0
				n.position = pd["start"]
				n.hum.rotation.z = 0.0
				n.set_process(true)
		elif float(pd["t"]) > 0.0:
			pd["t"] = float(pd["t"]) - delta
			if float(pd["t"]) <= 0.0:
				n.hum.rotation.z = 0.0
				n.set_process(true)


func _physics_process(delta: float) -> void:
	if m == null:
		return
	if m.player.global_position.distance_to(C) < 150.0:
		_traffic(delta)
		if news_heli != null:
			news_heli.orbit(delta)
	_heli_logic(delta)
	if stars <= 0:
		if not police.is_empty():
			clear_t += delta
			if clear_t > 4.0:
				clear_wanted(true)
		return
	var inside: bool = m.in_club or m.in_house != "" or in_shop != "" or m.mode == "dead"
	var tgt: Vector3 = m.car.global_position if m.mode == "car" else m.player.global_position
	var near_min := 1e9
	spawn_t -= delta
	police = police.filter(func(p: Variant) -> bool: return is_instance_valid(p))
	if police.size() < mini(stars + 1, 4) and spawn_t <= 0.0:
		spawn_t = 4.0
		_spawn_police(tgt)
	cop_spawn_t -= delta
	cops = cops.filter(func(c: Variant) -> bool: return is_instance_valid(c))
	var alive := 0
	for c in cops:
		if not (c as Cop3D).dying:
			alive += 1
	if stars >= 3 and alive < mini(stars - 1, 4) and cop_spawn_t <= 0.0 and not inside and tgt.distance_to(C) < 75.0:
		cop_spawn_t = 5.0
		var cp := Cop3D.new()
		var sx := clampf(tgt.x + (16.0 if randf() < 0.5 else -16.0), C.x - 44.0, C.x + 44.0)
		cp.position = Vector3(sx, 0.1, C.z + randf_range(-1.5, 1.5))
		m.world.add_child(cp)
		cops.append(cp)
	var chest: Vector3 = tgt + Vector3(0, 1.1, 0)
	for c in cops:
		var cc := c as Cop3D
		if cc.think(delta, tgt, not inside):
			var from := cc.global_position + Vector3(0, 1.3, 0)
			var hit := stars >= 3 and randf() < (0.1 if m.mode == "car" else 0.2)
			var endp := chest if hit else chest + Vector3(randf_range(-1.5, 1.5), randf_range(-0.6, 0.6), randf_range(-1.5, 1.5))
			m.weapons.tracer(from, endp, Color("ff9a6a"))
			Sfx.play("shot", 1.3)
			if hit and m.mode != "car":
				m.player.invuln = 0.0
				m.player.hurt(4.0, cc.global_position, 2.5)
			elif hit:
				Game.hp = maxf(1.0, Game.hp - 2.0)
	var pfoot_hit := 0.0
	for p in police:
		var pc := p as Car3D
		var to := tgt - pc.global_position
		to.y = 0.0
		var dist := to.length()
		near_min = minf(near_min, dist)
		var fwd := -pc.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var ang := fwd.signed_angle_to(to.normalized(), Vector3.UP)
		var steer := -clampf(ang * 2.2, -1.0, 1.0)
		var thr := 1.0
		if inside or dist < 4.0:
			thr = 0.0
		elif dist < 12.0:
			thr = 0.55
		if absf(ang) > 1.5 and dist > 8.0:
			thr = 0.45
		# застряли — сдаём назад
		var stuck: float = float(pc.get_meta("stuck", 0.0))
		var rev: float = float(pc.get_meta("rev", 0.0))
		if rev > 0.0:
			rev -= delta
			pc.set_meta("rev", rev)
			thr = -0.8
			steer = -steer
		else:
			if thr > 0.3 and absf(pc.speed) < 1.5:
				stuck += delta
			else:
				stuck = maxf(0.0, stuck - delta)
			if stuck > 1.2:
				stuck = 0.0
				pc.set_meta("rev", 1.0)
			pc.set_meta("stuck", stuck)
		pc.drive(thr, steer, delta)
		if m.mode != "car" and dist < 2.4 and absf(pc.speed) > 7.0 and ram_cd <= 0.0:
			ram_cd = 2.6
			m.player.invuln = 0.0
			m.player.hurt(6.0, pc.global_position, 9.0, 4.0, 0.9)
		if dist < 6.0:
			pfoot_hit = 1.0
	# арест: рядом милиция, а ты почти стоишь
	var slow: bool = (m.mode != "car" and m.player.cur_speed < 3.0) or (m.mode == "car" and absf(m.car.speed) < 3.0)
	if pfoot_hit > 0.0 and slow and not inside:
		bust_t += delta
		if bust_t > 2.2:
			_bust()
			return
	else:
		bust_t = maxf(0.0, bust_t - delta * 1.5)
	# снижение розыска, если оторвался
	if near_min > 55.0 or inside:
		clear_t += delta * (2.0 if inside else 1.0)
		if clear_t > 9.0:
			clear_t = 0.0
			heat = maxf(0.0, heat - 1.0)
			stars = ceili(heat - 0.001)
			if stars <= 0:
				clear_wanted()
			else:
				_toast("Розыск снизился: %s" % "★".repeat(stars), Color("ffd23a"))
	else:
		clear_t = 0.0


func _spawn_police(tgt: Vector3) -> void:
	var ang := randf() * TAU
	var pos := C + Vector3(0, 0, 8.2)
	if Vector2(pos.x - tgt.x, pos.z - tgt.z).length() > 160.0:
		return
	var pc := Car3D.new()
	pc.kind = "police"
	pc.ai = true
	pc.position = pos + Vector3(cos(ang) * 2.0, 0, 0)
	m.world.add_child(pc)
	police.append(pc)
	Sfx.play("howl", 1.7)


func _bust() -> void:
	var fine: int = mini(Game.cash, maxi(50, int(Game.cash * 0.3)))
	Game.cash -= fine
	Game.changed.emit()
	clear_wanted(true)
	if m.mode == "car":
		m._exit_car()
	m.player.global_position = m.SPAWN
	m.player.velocity = Vector3.ZERO
	_dlg("Милиционер", ["Стоять, дачник! Вы арестованы за хулиганство.", "Штраф $%d. В следующий раз — на пятнадцать суток." % fine, "Свободен. Доброе утро!"])
	Sfx.play("hurt")

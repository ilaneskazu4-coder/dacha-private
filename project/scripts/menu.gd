extends Node3D
## Главное меню: ночная поляна, камера медленно облетает костёр.

var cam: Camera3D
var env: Environment
var fire_light: OmniLight3D
var ui: MenuUI
var t := 0.0
var sparks: Array = []
var eyes: Array = []
var page := "main"
var car: Car3D
var starting := false
var osk: Osk
var coop_msg := ""
var find_sig := ""
var entry_mode := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--smoke") or a == "--snapshot" or a == "--game":
			_go.call_deferred()
			return
	Loc.set_lang(Settings.resolve_lang())
	MeshKit.set_detail(Settings.quality)
	_build_env()
	_build_world()
	_build_ui()
	Settings.changed.connect(_on_settings)
	Sfx.set_music(1.0)
	Ysdk.game_ready()
	Ysdk.show_banner()
	if "--shot-coop" in args:
		var sc := Node.new()
		sc.set_script(load("res://scripts/smoke_coop_menu.gd"))
		add_child(sc)
	if "--shot-menu" in args:
		var sm := Node.new()
		sm.set_script(load("res://scripts/smoke_menu.gd"))
		add_child(sm)


func _go() -> void:
	get_tree().change_scene_to_file("res://main.tscn")


func _build_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("050818")
	sm.sky_horizon_color = Color("1a2347")
	sm.ground_horizon_color = Color("1a2347")
	sm.ground_bottom_color = Color("070b14")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a5aa8")
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_light_color = Color("141a38")
	env.fog_density = 0.016
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_quality_env()
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38, 40, 0)
	moon.light_color = Color("8aa4ff")
	moon.light_energy = 0.4
	moon.shadow_enabled = Settings.quality >= 1
	moon.directional_shadow_max_distance = 40.0
	add_child(moon)


func _quality_env() -> void:
	env.glow_enabled = Settings.quality >= 2
	env.glow_intensity = 0.9
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 0.9
	env.adjustment_enabled = Settings.quality >= 1
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12


func _on_settings() -> void:
	MeshKit.set_detail(Settings.quality)
	_quality_env()
	Loc.set_lang(Settings.resolve_lang())
	_show_page(page)


func _build_world() -> void:
	# земля
	MeshKit.inst([MeshKit.box(Vector3(260, 0.4, 260), Vector3(0, -0.2, 0), Color("2c5a30")),
		MeshKit.cyl(7.0, 7.0, 0.05, Vector3(0, 0.02, 0), Color("4a3a28"), Vector3.ZERO, 24),
		MeshKit.cyl(4.2, 4.2, 0.06, Vector3(0, 0.03, 0), Color("5a4630"), Vector3.ZERO, 20)], self)
	MeshKit.static_box(self, Vector3(260, 0.4, 260), Vector3(0, -0.2, 0))
	# костёр
	var fire := Structure3D.new()
	add_child(fire)
	fire.setup("fire", 0)
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(0, 1.3, 0)
	fire_light.light_color = Color("ff9a45")
	fire_light.light_energy = 2.6
	fire_light.omni_range = 16.0
	fire_light.shadow_enabled = Settings.quality >= 2
	add_child(fire_light)
	# брёвна-лавки вокруг
	for a in [0.9, 2.3, 4.2, 5.3]:
		var p := Vector3(cos(a) * 3.1, 0.0, sin(a) * 3.1)
		MeshKit.inst([MeshKit.cyl(0.26, 0.26, 2.0, Vector3(0, 0.26, 0), Color("6b4423"), Vector3(0, 0, PI / 2), 9),
			MeshKit.cyl(0.2, 0.2, 0.04, Vector3(1.0, 0.26, 0), Color("c9a05a"), Vector3(0, 0, PI / 2), 9)], self, p).rotation.y = -a + PI / 2
	# лес вокруг поляны
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 46:
		var a := rng.randf() * TAU
		var r := rng.randf_range(13.0, 48.0)
		var v := rng.randi() % 4
		var tr := MeshKit.inst(Forest.variant_parts(v), self, Vector3(cos(a) * r, 0, sin(a) * r))
		tr.scale = Vector3.ONE * rng.randf_range(0.9, 1.5)
		tr.rotation.y = rng.randf() * TAU
	for i in 14:
		var a2 := rng.randf() * TAU
		var r2 := rng.randf_range(9.0, 30.0)
		MeshKit.inst(Forest.variant_parts(4 + (i % 2)), self, Vector3(cos(a2) * r2, 0, sin(a2) * r2)).scale = Vector3.ONE * rng.randf_range(0.8, 1.6)
	# дача в глубине
	var h := WorldBuilder.house("ДАЧА МИХАЛЫЧА", Color("c9b07a"), Color("8a3b2a"), 9.0, 7.0)
	h.position = Vector3(-17, 0, -22)
	h.rotation.y = deg_to_rad(28.0)
	add_child(h)
	# Пассат с включёнными фарами
	car = Car3D.new()
	car.position = Vector3(15, 0, -9)
	car.rotation.y = deg_to_rad(-58.0)
	add_child(car)
	car.set_lights(true)
	# компания у костра
	_person("mikhalych", {"skin": Color("e7b48a"), "shirt": Color("b3261e"), "pants": Color("2f4a7a"), "shoes": Color("4a2d1c"),
		"hat": "beanie", "hat_col": Color("e08a1e"), "beard": true, "beard_col": Color("6b4423"), "stripes": true}, 3.5, 3.2)
	_person("makar", {"shirt": Color("5a6a8a"), "pants": Color("3a3a4a"), "hat": "cap", "hat_col": Color("5a4a3a"),
		"beard": true, "beard_col": Color("c8c8c8"), "skin": Color("e0b890")}, 0.3, 3.3)
	_person("kolya", {"shirt": Color("2a6aa8"), "pants": Color("2a3a5a"), "hat": "none", "skin": Color("d9a578")}, 5.2, 3.4)
	# звёзды и луна
	var stars: Array = []
	var srng := RandomNumberGenerator.new()
	srng.seed = 3
	for i in 140:
		var az := srng.randf() * TAU
		var el := srng.randf_range(0.25, 1.4)
		var rr := 170.0
		var sz := srng.randf_range(0.35, 0.9)
		stars.append(MeshKit.box(Vector3(sz, sz, sz), Vector3(cos(az) * cos(el) * rr, sin(el) * rr, sin(az) * cos(el) * rr), Color.WHITE))
	var sg := MeshKit.glow_inst(stars, Color("e8eeff"), self, 2.2)
	sg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var moon_mesh := MeshKit.glow_inst([MeshKit.sph(9.0, Vector3(70, 85, -130), Color.WHITE, Vector3.ONE, 14)], Color("f4f0d8"), self, 2.0)
	moon_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# окна дачи горят
	for wm in WorldBuilder.win_mats:
		(wm as StandardMaterial3D).emission_energy_multiplier = 2.6
		(wm as StandardMaterial3D).albedo_color = Color("ffd890")
	# искры
	var spm := SphereMesh.new()
	spm.radius = 0.05
	spm.height = 0.1
	spm.radial_segments = 5
	spm.rings = 2
	var smat := MeshKit.glow_mat(Color("ffb040"), 4.0)
	for i in 26:
		var mi := MeshInstance3D.new()
		mi.mesh = spm
		mi.material_override = smat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		sparks.append({"n": mi, "ph": randf() * 4.0, "sp": randf_range(0.7, 1.5), "ox": randf_range(-0.4, 0.4), "oz": randf_range(-0.4, 0.4)})
	# глаза волков в темноте
	var emesh := SphereMesh.new()
	emesh.radius = 0.07
	emesh.height = 0.14
	emesh.radial_segments = 6
	emesh.rings = 3
	var emat := MeshKit.glow_mat(Color("e8ff5a"), 3.5)
	for k in 4:
		var a3 := 0.5 + k * 1.55 + rng.randf() * 0.4
		var r3 := rng.randf_range(24.0, 32.0)
		var c := Vector3(cos(a3) * r3, 0.85, sin(a3) * r3)
		var pair := Node3D.new()
		pair.position = c
		pair.rotation.y = -a3 - PI / 2
		for sx in [-0.16, 0.16]:
			var e := MeshInstance3D.new()
			e.mesh = emesh
			e.material_override = emat
			e.position = Vector3(sx, 0, 0)
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pair.add_child(e)
		add_child(pair)
		eyes.append({"n": pair, "ph": rng.randf() * 10.0})
	# камера
	cam = Camera3D.new()
	cam.fov = 58.0
	cam.near = 0.3
	cam.far = 220.0
	add_child(cam)
	cam.make_current()
	_orbit(0.0)


func _person(id: String, style: Dictionary, ang: float, r: float) -> void:
	var n := Npc3D.new()
	n.id = id
	n.position = Vector3(cos(ang) * r, 0, sin(ang) * r)
	n.rotation.y = atan2(cos(ang), sin(ang))
	n.base_yaw = n.rotation.y
	add_child(n)
	n.setup("", style, false)
	n.name_lbl.visible = false
	n.mark_lbl.visible = false


func _orbit(tt: float) -> void:
	var a := tt * 0.11 + 0.6
	var r := 8.6 + sin(tt * 0.07) * 1.2
	var h := 2.3 + sin(tt * 0.13) * 0.55
	cam.position = Vector3(cos(a) * r, h, sin(a) * r)
	cam.look_at(Vector3(0, 1.15 + sin(tt * 0.1) * 0.1, 0), Vector3.UP)


func _process(delta: float) -> void:
	if page == "find" and Net.searching:
		_refresh_find()
	t += delta
	if cam == null:
		return
	_orbit(t)
	fire_light.light_energy = 2.4 + sin(t * 13.0) * 0.35 + sin(t * 7.3) * 0.25
	for s in sparks:
		var ph: float = fmod(t * float(s["sp"]) + float(s["ph"]), 3.0)
		var n: MeshInstance3D = s["n"]
		n.position = Vector3(float(s["ox"]) + sin(ph * 2.0 + float(s["ph"])) * 0.4, 0.8 + ph * 1.3, float(s["oz"]) + cos(ph * 1.7) * 0.4)
		n.scale = Vector3.ONE * clampf(1.2 - ph / 3.0, 0.1, 1.2)
	for e in eyes:
		var n2: Node3D = e["n"]
		n2.visible = fmod(t * 0.4 + float(e["ph"]), 6.0) < 4.6


# ---------- интерфейс ----------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui = MenuUI.new()
	ui.left_layout = true
	layer.add_child(ui)
	ui.action.connect(_on_action)
	osk = Osk.new()
	layer.add_child(osk)
	osk.done.connect(_on_osk_done)
	Net.lobby_changed.connect(_on_lobby_changed)
	Net.join_failed.connect(_on_join_failed)
	Net.left.connect(_on_net_left)
	_show_page("main")


func _show_page(p: String) -> void:
	page = p
	match p:
		"main":
			var cont: bool = Game.intro_done
			var its: Array = [{"t": "btn", "id": "play", "label": "Продолжить" if cont else "Играть", "accent": true}]
			if cont:
				its.append({"t": "btn", "id": "new", "label": "Новая игра"})
			its.append({"t": "btn", "id": "coop", "label": "Играть вместе (друзья)"})
			its.append({"t": "btn", "id": "settings", "label": "Настройки"})
			its.append({"t": "btn", "id": "about", "label": "Об игре"})
			ui.set_items("ДАЧА МИХАЛЫЧА", its, "выживание в лесу")
		"coop":
			var cl: Array = [
				{"t": "text", "label": "Твоё имя: %s" % Settings.nick},
				{"t": "btn", "id": "host_online", "label": "Создать комнату (код)", "accent": true},
				{"t": "btn", "id": "code", "label": "Войти по коду"},
				{"t": "btn", "id": "wifi", "label": "Без интернета (Wi-Fi)"},
				{"t": "btn", "id": "conn", "label": "Имя и сервер"}]
			if coop_msg != "":
				cl.append({"t": "text", "label": coop_msg})
			cl.append({"t": "btn", "id": "back", "label": "Назад"})
			ui.set_items("Играть вместе", cl, "до 4 игроков, бесплатно")
		"wifi":
			ui.set_items("Комната в Wi-Fi", [
				{"t": "btn", "id": "host", "label": "Создать комнату", "accent": true},
				{"t": "btn", "id": "find", "label": "Найти комнату в сети"},
				{"t": "btn", "id": "ip", "label": "Ввести адрес вручную"},
				{"t": "btn", "id": "back_coop", "label": "Назад"}], "одна сеть или раздача с телефона")
		"conn":
			ui.set_items("Имя и сервер", [
				{"t": "text", "label": "Имя: %s" % Settings.nick},
				{"t": "btn", "id": "name", "label": "Изменить имя"},
				{"t": "btn", "id": "url", "label": "Адрес сервера"},
				{"t": "btn", "id": "back_coop", "label": "Назад"}], "сервер нужен для игры по коду")
		"lobby":
			_show_lobby()
		"find":
			find_sig = ""
			_refresh_find()
		"entry":
			ui.set_items("Введи адрес комнаты" if entry_mode == "ip" else "Твоё имя", [
				{"t": "gap"}, {"t": "gap"}, {"t": "gap"}, {"t": "gap"},
				{"t": "btn", "id": "entry_ok", "label": "Подключиться" if entry_mode == "ip" else "Сохранить", "accent": true},
				{"t": "btn", "id": "back_coop", "label": "Назад"}],
				"адрес из строки «Твой адрес» у хозяина" if entry_mode == "ip" else "его увидят друзья")
		"settings":
			ui.set_items("Настройки", MenuUI.settings_items())
		"confirm":
			ui.set_items("Начать заново?", [
				{"t": "text", "label": "Весь прогресс будет стёрт."},
				{"t": "btn", "id": "new_yes", "label": "Да, начать заново", "accent": true},
				{"t": "btn", "id": "back", "label": "Отмена"}])
		"about":
			ui.set_items("Об игре", [
				{"t": "text", "label": "Руби лес, строй костёр, пережди ночь."},
				{"t": "text", "label": "Узнай, кто приваживает волков к даче."},
				{"t": "text", "label": "Управление: стик слева, камера справа."},
				{"t": "text", "label": "Пауза: значок вверху или клавиша Esc."},
				{"t": "gap"},
				{"t": "btn", "id": "back", "label": "Назад"}])


func _show_lobby() -> void:
	var its: Array = []
	var ids: Array = Net.players.keys()
	ids.sort()
	var n := 1
	for pid in ids:
		var tag := " (хозяин)" if int(pid) == 1 else ""
		its.append({"t": "text", "label": "%d. %s%s" % [n, Net.players[pid]["name"], tag]})
		n += 1
	if Net.online:
		its.append({"t": "text", "label": "КОД КОМНАТЫ: %s" % Net.room_code})
	if Net.is_host:
		if not Net.online:
			its.append({"t": "text", "label": "Твой адрес: %s" % Net.my_address()})
		its.append({"t": "btn", "id": "pvp_lobby", "label": "PvP (драки): " + ("включено" if Net.pvp else "выключено")})
		its.append({"t": "btn", "id": "start_coop", "label": "Начать игру (%d/4)" % Net.players.size(), "accent": true})
	else:
		its.append({"t": "text", "label": "Ждём, пока хозяин начнёт игру…"})
	its.append({"t": "btn", "id": "leave_lobby", "label": "Выйти из комнаты"})
	ui.set_items("Комната", its, "друзья ищут её в «Играть вместе»")


func _refresh_find() -> void:
	var sig := ",".join(Net.rooms.keys())
	if sig == find_sig and find_sig != "x":
		return
	find_sig = sig
	var its: Array = []
	if Net.rooms.is_empty():
		its.append({"t": "text", "label": "Ищем комнаты в вашей Wi-Fi сети…"})
		its.append({"t": "text", "label": "Хозяин должен создать комнату"})
	else:
		for ip in Net.rooms:
			var r: Dictionary = Net.rooms[ip]
			its.append({"t": "btn", "id": "room:" + String(ip), "label": "%s (%d/4)" % [r["name"], int(r["n"])]})
	its.append({"t": "gap"})
	its.append({"t": "btn", "id": "back_coop", "label": "Назад"})
	ui.set_items("Комнаты рядом", its)


func _on_lobby_changed() -> void:
	if Net.in_lobby and page != "lobby":
		ui.loading = ""
		_show_page("lobby")
	elif page == "lobby":
		if Net.in_lobby:
			_show_lobby()
		else:
			_show_page("coop")


func _on_join_failed(msg: String) -> void:
	ui.loading = ""
	coop_msg = msg
	_show_page("coop")


func _on_net_left(msg: String) -> void:
	if msg != "":
		coop_msg = msg
	if page == "lobby":
		_show_page("coop")


func _on_osk_done(tx: String, ok: bool) -> void:
	if not ok:
		return
	if tx == "" and entry_mode != "url":
		return
	match entry_mode:
		"name":
			if tx != "":
				Settings.nick = tx.substr(0, 14)
				Net.my_name = Settings.nick
				Settings.save()
				Settings.notify()
				_show_page("coop")
		"ip":
			ui.loading = "Подключаемся…"
			Net.join(tx)
		"code":
			ui.loading = "Подключаемся…"
			Net.join_online(tx)
		"url":
			Settings.relay = tx
			Settings.save()
			coop_msg = "Адрес сервера сохранён"
			_show_page("coop")


func _on_action(id: String, value: Variant) -> void:
	if id.begins_with("room:"):
		ui.loading = "Подключаемся…"
		Net.stop_search()
		Net.join(id.substr(5))
		return
	if MenuUI.apply_setting(id, value):
		return
	match id:
		"coop":
			coop_msg = ""
			_show_page("coop")
		"wifi", "conn":
			_show_page(id)
		"host_online":
			coop_msg = ""
			Net.host_online()
		"host":
			coop_msg = ""
			if Net.host_room():
				_show_page("lobby")
		"find":
			Net.start_search()
			_show_page("find")
		"ip", "name", "code", "url":
			entry_mode = id
			match id:
				"name":
					osk.open("Твоё имя", Settings.nick, 14, "его увидят друзья")
				"ip":
					osk.open("Адрес комнаты (Wi-Fi)", "", 40, "из строки «Твой адрес» у хозяина")
				"code":
					osk.open("Код комнаты", "", 6, "его скажет хозяин", true)
				"url":
					osk.open("Адрес сервера", Settings.relay, 80, "https://….workers.dev")
		"back_coop":
			Net.stop_search()
			_show_page("coop")
		"leave_lobby":
			Net.leave(false)
			_show_page("coop")
		"start_coop":
			Net.begin_game()
		"pvp_lobby":
			Net.set_pvp(not Net.pvp)
		"play":
			_start(false)
		"new":
			_show_page("confirm")
		"new_yes":
			_start(true)
		"settings":
			_show_page("settings")
		"about":
			_show_page("about")
		"back":
			if page in ["find", "entry", "wifi", "conn"]:
				Net.stop_search()
				_show_page("coop")
			elif page == "lobby":
				Net.leave(false)
				_show_page("coop")
			else:
				_show_page("main")


func _start(fresh: bool) -> void:
	if starting:
		return
	starting = true
	if fresh:
		Game.reset_all()
	ui.loading = "Загрузка..."
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file("res://main.tscn")

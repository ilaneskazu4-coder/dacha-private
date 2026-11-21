extends Node3D
## Дача Михалыча: выживание. Большая карта, день/ночь, стройка, волки, реклама за возрождение.

const HALF := DachaBuilder.HALF
const MAX_STRUCTS := 120
const SPAWN := Vector3(0, 0, -2)
const CLUB_OFF := Vector3(500, 0, 0)
const CLUB_DOOR := Vector3(-78, 0, 44.5)
const DRINK_COST := 2
const DRINKS := ["Квас «Берёзка»", "Морс «Клюква-бомба»", "Лимонад «Дача-кола»", "Компот «Тройной»", "Энергетик «Волчий вой»"]
const SAWMILL_POS := Vector3(-80, 0, -60)
const TOWER_POS := Vector3(70, 0, -80)
const HOUSE_ORDER := ["home", "shed", "makar", "lyuda", "bytovka", "shop"]
## pos — центр здания, rot — поворот (градусы), dx — смещение двери вдоль фасада, d — глубина здания
const HOUSES := {
	"home": {"pos": Vector3(0, 0, -12), "rot": 0.0, "dx": 0.0, "d": 7.0},
	"shed": {"pos": Vector3(-14, 0, -16), "rot": 90.0, "dx": -4.0, "d": 8.0},
	"makar": {"pos": Vector3(-33, 0, 8), "rot": 90.0, "dx": 0.0, "d": 7.0},
	"lyuda": {"pos": Vector3(58, 0, -4), "rot": 0.0, "dx": 0.0, "d": 7.0},
	"bytovka": {"pos": Vector3(-62, 0, -52), "rot": 0.0, "dx": 0.0, "d": 5.5},
	"shop": {"pos": Vector3(15, 0, 48), "rot": -90.0, "dx": 0.0, "d": 6.5},
}
const RADIO := ["«...по всему району — ясная погода, к вечеру возможны волки. Передавали Сергей и Маша.»",
	"«В эфире программа «Всё для дачи»: как отвадить волка от забора. Совет первый: забор.»",
	"«Песня по заявке деда Макара: «Ой, мороз, мороз». Заявок больше не было.»",
	"«Новости: на лесопилке обнаружена пропавшая пила. Ну, не обнаружена. Но обещали.»"]
const SHOP_ITEMS := [["Пирожок с капустой", 2, 30], ["Чай с мятой", 1, 15], ["Сосиска в тесте", 3, 45]]

var world: Node3D
var structs_root: Node3D
var wolves_root: Node3D
var player: Player3D
var buddy: Player3D
var buddy_ai: BuddyAI
var buddy2: Player3D
var buddy2_ai: BuddyAI
var mission: Mission1 = null
var car_seq := ""
var seq_t := 0.0
var seq_from := Vector3.ZERO
var shake_t := 0.0
var cam_off := 0.55
var cam_fov := 66.0
var switch_cd := 0.0
var car: Car3D
var makar: Npc3D
var npcs := {}
var near_npc: Npc3D
var q_reached := false
var fish_cd := 0.0
var boss_pending := false
var club: Club3D
var club_front: Node3D
var club_npcs := {}
var in_club := false
var in_house := ""
var interiors := {}
var houses_nodes := {}
var looted := {}
var clouds: Node3D
var cloud_mat: StandardMaterial3D
var flies: Array = []
var player_light: OmniLight3D
var base_scale := 1.0
var pause_ui: MenuUI
var pause_page := ""
var atmo_t := 0.0
var bed_cd := 0.0
var pie_cd := 0.0
var shop_i := 0
var transitioning := false
var drunk := 0.0
var drunk_t := 0.0
var dance_t := 0.0
var drink_i := 0
var fish_speed := 1.0
var fish_dir := 1.0
const FISH_SPOT := Vector3(66, 0, 22)
var forest: Forest
var dn: DayNight
var sun: DirectionalLight3D
var env: Environment

var cam_rig: Node3D
var spring: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := 0.38

var ui: TouchUI
var ui_layer: CanvasLayer

var mode := "play"          # play, car, dialog, dead, ad
var build_mode := false
var hot_sel := 0
var rot_extra := 0
var ghost: Node3D
var ghost_kind := ""
var ghost_ok := false
var ghost_pos := Vector3.ZERO
var ghost_rot := 0

var shout_cd := 0.0
var wave_total := 0
var wave_spawned := 0
var spawn_t := 0.0
var night_kills := 0
var save_t := 0.0
var rng := RandomNumberGenerator.new()
var fun: Node = null
var city: Node = null
var weapons: Node = null
var cars: Array = []
var ghost_mat := StandardMaterial3D.new()


func _ready() -> void:
	Loc.set_lang(Settings.resolve_lang())
	rng.seed = 77
	var cargs := OS.get_cmdline_user_args()
	Npc3D.frozen = "--smoke" in cargs or "--smoke-mission" in cargs or "--smoke-quest" in cargs or "--smoke-houses" in cargs
	_build_env()
	_build_world()
	_build_player_and_camera()
	_build_ui()
	city = Node.new()
	city.set_script(load("res://scripts/city.gd"))
	add_child(city)
	weapons = Node.new()
	weapons.set_script(load("res://scripts/weapons.gd"))
	add_child(weapons)
	mission = Mission1.new()
	add_child(mission)
	mission.setup(self, city)
	for nid in npcs:
		(npcs[nid] as Npc3D).face_to = player
	for hid in HOUSE_ORDER:
		_get_interior(hid)
	_build_atmo()
	_build_pause_ui()
	_apply_quality()
	Settings.changed.connect(_apply_quality)
	_restore_structs()
	dn.day = Game.day
	dn.night_started.connect(_on_night)
	dn.dawn_started.connect(_on_dawn)
	dn.day_started.connect(_on_day)
	Ysdk.ad_result.connect(_on_ad_result)
	Ysdk.cloud_loaded.connect(_on_cloud)
	if not Net.active:
		Ysdk.cloud_load()
	if "--snapshot" in OS.get_cmdline_user_args():
		_snapshot.call_deferred()
		return
	Ysdk.game_ready()
	Ysdk.show_banner()
	Ysdk.gameplay(true)
	if "--smoke" in OS.get_cmdline_user_args() or "--smoke-quest" in OS.get_cmdline_user_args() or "--smoke-store" in OS.get_cmdline_user_args() or "--smoke-video" in OS.get_cmdline_user_args() or "--smoke-houses" in OS.get_cmdline_user_args() or "--smoke-gfx" in OS.get_cmdline_user_args() or "--smoke-pause" in OS.get_cmdline_user_args() or "--smoke-trailer" in OS.get_cmdline_user_args():
		var sm := Node.new()
		sm.set_script(load("res://scripts/smoke_trailer.gd" if "--smoke-trailer" in OS.get_cmdline_user_args() else "res://scripts/smoke_pause.gd" if "--smoke-pause" in OS.get_cmdline_user_args() else "res://scripts/smoke_gfx.gd" if "--smoke-gfx" in OS.get_cmdline_user_args() else "res://scripts/smoke_houses.gd" if "--smoke-houses" in OS.get_cmdline_user_args() else "res://scripts/smoke_video.gd" if "--smoke-video" in OS.get_cmdline_user_args() else ("res://scripts/smoke_store.gd" if "--smoke-store" in OS.get_cmdline_user_args() else ("res://scripts/smoke_quest.gd" if "--smoke-quest" in OS.get_cmdline_user_args() else "res://scripts/smoke.gd"))))
		add_child(sm)
	if "--smoke-traffic" in OS.get_cmdline_user_args():
		var st := Node.new()
		st.set_script(load("res://scripts/smoke_traffic.gd"))
		add_child(st)
	if "--smoke-guns" in OS.get_cmdline_user_args():
		var sg := Node.new()
		sg.set_script(load("res://scripts/smoke_guns.gd"))
		add_child(sg)
	if "--smoke-hero" in OS.get_cmdline_user_args():
		var sh := Node.new()
		sh.set_script(load("res://scripts/smoke_hero.gd"))
		add_child(sh)
	if "--smoke-char" in OS.get_cmdline_user_args():
		var sch := Node.new()
		sch.set_script(load("res://scripts/smoke_char.gd"))
		add_child(sch)
	if "--smoke-shots" in OS.get_cmdline_user_args():
		var ssh := Node.new()
		ssh.set_script(load("res://scripts/smoke_shots.gd"))
		add_child(ssh)
	if "--smoke-mission" in OS.get_cmdline_user_args():
		var smh := Node.new()
		smh.set_script(load("res://scripts/smoke_mission.gd"))
		add_child(smh)
	if "--smoke-city" in OS.get_cmdline_user_args():
		var sc := Node.new()
		sc.set_script(load("res://scripts/smoke_city.gd"))
		add_child(sc)
	if Net.active:
		Net.attach(self)
		fun = Node.new()
		fun.set_script(load("res://scripts/coop_fun.gd"))
		add_child(fun)
		if "--smoke-fun" in OS.get_cmdline_user_args():
			var sf := Node.new()
			sf.set_script(load("res://scripts/smoke_fun.gd"))
			add_child(sf)
		if "--smoke-net" in OS.get_cmdline_user_args():
			var sn := Node.new()
			sn.set_script(load("res://scripts/smoke_net.gd"))
			add_child(sn)
	if not Game.intro_done:
		_intro.call_deferred()


# ---------------- построение ----------------

func _build_env() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 42.0
	add_child(sun)
	dn = DayNight.new()
	add_child(dn)
	dn.setup(sun, env, sky_mat)
	ghost_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.42)
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func _build_world() -> void:
	WorldBuilder.win_mats.clear()
	WorldBuilder.porch_lights.clear()
	world = Node3D.new()
	add_child(world)
	structs_root = Node3D.new()
	add_child(structs_root)
	wolves_root = Node3D.new()
	add_child(wolves_root)
	DachaBuilder.ground(world)
	DachaBuilder.lake(world)
	DachaBuilder.fence(world)
	DachaBuilder.garden(world)
	DachaBuilder.well(world, Vector3(13, 0, 6))
	DachaBuilder.tower(world, TOWER_POS)

	var house := WorldBuilder.house(Loc.t("ДАЧА МИХАЛЫЧА"), Color("c9a46a"), Color("8a2f26"))
	house.position = Vector3(0, 0, -12)
	world.add_child(house)
	var shed := WorldBuilder.garage(Loc.t("САРАЙ"))
	shed.position = Vector3(-14, 0, -16)
	shed.rotation.y = deg_to_rad(90)
	world.add_child(shed)
	_build_houses()
	var saw := WorldBuilder.sawmill(Loc.t("ЛЕСОПИЛКА"))
	saw.position = SAWMILL_POS
	world.add_child(saw)
	var logs := WorldBuilder.log_pile()
	logs.position = Vector3(12, 0, -14)
	world.add_child(logs)
	for sp in [[Vector3(4, 0, 18), "ДАЧА >"], [Vector3(-6, 0, 24), "< ЛЕСОПИЛКА 100м"], [Vector3(6, 0, 30), "ОЗЕРО >"]]:
		var s := WorldBuilder.sign_post(Loc.t(sp[1]))
		s.position = sp[0]
		s.rotation.y = deg_to_rad(180)
		world.add_child(s)

	var fs := WorldBuilder.sign_post(Loc.t("РЫБАЛКА"))
	fs.position = FISH_SPOT + Vector3(-2.6, 0, 0.5)
	fs.rotation.y = deg_to_rad(180)
	world.add_child(fs)

	club_front = WorldBuilder.club_front()
	club_front.position = Vector3(-78, 0, 38)
	world.add_child(club_front)
	var cs := WorldBuilder.sign_post(Loc.t("< ДИСКО 80м"))
	cs.position = Vector3(-6, 0, 34)
	cs.rotation.y = deg_to_rad(180)
	world.add_child(cs)
	club = Club3D.new()
	club.position = CLUB_OFF
	add_child(club)
	_build_club_npcs()

	makar = Npc3D.new()
	makar.id = "makar"
	makar.position = Vector3(0, 0, 12.5)
	makar.base_yaw = 0.0
	world.add_child(makar)
	makar.setup(Loc.t("Дед Макар"), {"shirt": Color("6a7a58"), "pants": Color("4a3a2a"), "hat": "cap",
		"hat_col": Color("3a3a3a"), "beard": true, "beard_col": Color("d8d8d8")})
	npcs["makar"] = makar
	npcs["kolya"] = _mk_npc("kolya", Loc.t("Коля-сантехник"), {"shirt": Color("2d5fa8"), "pants": Color("2d5fa8"),
		"hat": "cap", "hat_col": Color("c2552b"), "skin": Color("d9a578")}, Vector3(-74, 0, -50), 200.0)
	npcs["lyuda"] = _mk_npc("lyuda", Loc.t("Баба Люда"), {"shirt": Color("a84a8a"), "pants": Color("5a3a6a"),
		"hat": "none", "skin": Color("e7b48a")}, Vector3(66, 0, 12), 90.0)

	_build_town_npcs()

	car = Car3D.new()
	car.position = Vector3(9, 0, 10)
	car.rotation.y = deg_to_rad(20)
	world.add_child(car)
	cars.append(car)

	forest = Forest.new()
	add_child(forest)
	var ok := func(p: Vector3) -> bool:
		if DachaBuilder.DACHA.grow(7.0).has_point(Vector2(p.x, p.z)):
			return false
		if absf(p.x) < 5.0 and p.z > 16.0 and p.z < 70.0:
			return false
		if Vector2(p.x - DachaBuilder.LAKE_C.x, p.z - DachaBuilder.LAKE_C.z).length() < DachaBuilder.LAKE_R + 5.0:
			return false
		if Vector2(p.x - SAWMILL_POS.x, p.z - SAWMILL_POS.z).length() < 15.0:
			return false
		if Vector2(p.x - TOWER_POS.x, p.z - TOWER_POS.z).length() < 8.0:
			return false
		if p.x > -6.0 and p.x < 102.0 and p.z > 58.0 and p.z < 100.0:
			return false
		for hid in HOUSES:
			var hp: Vector3 = HOUSES[hid]["pos"]
			if Vector2(p.x - hp.x, p.z - hp.z).length() < 9.0:
				return false
		return true
	forest.build(rng, 450, 60, ok, HALF)


func _build_player_and_camera() -> void:
	player = Player3D.new()
	player.style_idx = Net.my_idx() if Net.active else 0
	player.position = SPAWN
	add_child(player)
	player.chop_hit.connect(_on_chop_hit)
	player.special_hit.connect(func(k: int): special_effect(player, k, true))
	buddy = Player3D.new()
	buddy.is_buddy = true
	buddy.char_id = 1
	buddy.position = SPAWN + Vector3(2.5, 0, 2.0)
	buddy.charge = 0.5
	add_child(buddy)
	buddy_ai = BuddyAI.new()
	add_child(buddy_ai)
	buddy_ai.setup(self, buddy)
	buddy2 = Player3D.new()
	buddy2.is_buddy = true
	buddy2.char_id = 2
	buddy2.position = SPAWN + Vector3(-2.5, 0, 2.0)
	buddy2.charge = 0.5
	add_child(buddy2)
	buddy2_ai = BuddyAI.new()
	add_child(buddy2_ai)
	buddy2_ai.setup(self, buddy2)
	cam_rig = Node3D.new()
	add_child(cam_rig)
	spring = SpringArm3D.new()
	spring.spring_length = 4.6
	var sh := SphereShape3D.new()
	sh.radius = 0.3
	spring.shape = sh
	spring.add_excluded_object(player.get_rid())
	spring.add_excluded_object(buddy.get_rid())
	spring.add_excluded_object(buddy2.get_rid())
	spring.add_excluded_object(car.get_rid())
	cam_rig.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 68.0
	cam.near = 0.35
	cam.far = 190.0
	cam.current = true
	spring.add_child(cam)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	ui = TouchUI.new()
	ui_layer.add_child(ui)
	ui.hotbar = _hotbar_data()


func _hotbar_data() -> Array:
	var arr: Array = []
	for k in Structure3D.ORDER:
		var info: Dictionary = Structure3D.CAT[k]
		arr.append({"name": Loc.t(String(info["name"])), "wood": info["wood"], "stone": info["stone"],
			"ok": Game.can_afford(info["wood"], info["stone"])})
	arr.append({"name": Loc.t("Убрать"), "wood": 0, "stone": 0, "ok": true, "remove": true})
	return arr


# ---------------- сюжет ----------------

func _intro() -> void:
	await get_tree().create_timer(0.6).timeout
	mode = "dialog"
	ui.open_dialog("Дед Макар", [
		"О, Михалыч! Приехал-таки на дачу. Красота — тишина, птички, комары...",
		"Только ты это... к ночи тут волки гуляют. Здоровые. Голодные. Вчера у меня весь забор обгрызли.",
		"Бери топор и нарубай брёвен — десять штук. Из них сложишь костёр, волки огня боятся.",
		"Бей топором по деревьям, камни тоже бьются, пригодятся. Кнопка «Стройка» — ставить стены и забор.",
		"Пассат во дворе заправлен. Он, кстати, волков тоже давит. Ну всё, не пропади!",
	], func():
		Game.intro_done = true
		Game.save()
		mode = "play")


func _mk_npc(id: String, nm: String, style: Dictionary, pos: Vector3, yaw_deg: float, parent: Node3D = null) -> Npc3D:
	var n := Npc3D.new()
	n.id = id
	n.position = pos
	n.rotation.y = deg_to_rad(yaw_deg)
	n.base_yaw = n.rotation.y
	(parent if parent != null else world).add_child(n)
	n.setup(nm, style)
	return n


func _build_club_npcs() -> void:
	var cols := [Color("d83a8a"), Color("3ab8d8"), Color("e8c23a"), Color("7a3ad8"), Color("3ad87a"), Color("d8643a")]
	for i in 6:
		var a := i * TAU / 6.0
		var p := Vector3(cos(a) * 3.6, 0, -1.0 + sin(a) * 2.8)
		var n := _mk_npc("dancer%d" % i, "", {"shirt": cols[i], "pants": Color("2a2a44"), "dance": true,
			"hat": "none", "skin": [Color("e7b48a"), Color("c68a5a"), Color("f0c8a0")][i % 3]}, p, rad_to_deg(a), club)
		n.name_lbl.visible = false
		n.mark_lbl.visible = false
	var dj := _mk_npc("dj", Loc.t("Диджей Борис"), {"shirt": Color("1c1c24"), "pants": Color("1c1c24"), "shades": true,
		"skin": Color("d9a578")}, Vector3(0, 0.95, -7.6), 0.0, club)
	dj.mark_lbl.visible = false
	club_npcs["dj"] = dj
	var bz := _mk_npc("borzov", Loc.t("Борзов"), {"shirt": Color("15151a"), "pants": Color("1a1a22"), "shades": true,
		"hat": "none", "skin": Color("e0b890")}, Vector3(8.6, 0, -3.6), 90.0, club)
	npcs["borzov"] = bz
	var bar := _mk_npc("bartender", Loc.t("Бармен Эдик"), {"shirt": Color("f2f2f2"), "pants": Color("222233"),
		"beard": true, "beard_col": Color("3a2a1a")}, Vector3(-11.1, 0, -1.0), -90.0, club)
	bar.mark_lbl.visible = false
	club_npcs["bartender"] = bar


func _apply_quality() -> void:
	var q := Settings.quality
	MeshKit.set_detail(q)
	env.glow_enabled = q >= 2
	env.glow_intensity = 0.85
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 0.95
	env.adjustment_enabled = q >= 1
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.1
	base_scale = Settings.base_scale()
	get_viewport().scaling_3d_scale = base_scale if perf_level == 0 else minf(base_scale, [1.0, 0.8, 0.66, 0.5][perf_level])
	sun.shadow_enabled = q >= 1 and perf_level < 2
	sun.directional_shadow_max_distance = (30.0 if perf_level >= 1 else [20.0, 38.0, 56.0][q])
	if clouds != null:
		clouds.visible = q >= 1


# ---------------- пауза ----------------
func _build_pause_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	pause_ui = MenuUI.new()
	pause_ui.panel = true
	pause_ui.dim = 0.55
	pause_ui.visible = false
	layer.add_child(pause_ui)
	pause_ui.action.connect(_on_pause_action)


func _pause_game() -> void:
	if Ysdk.user_paused or transitioning or ui.dlg_active or ui.modal != "" or mode == "dead" or mode == "ad":
		return
	Ysdk.user_paused = true
	Ysdk.apply_pause()
	Ysdk.gameplay(false)
	_show_pause_page("pause")
	pause_ui.visible = true


func _resume_game() -> void:
	pause_ui.visible = false
	Ysdk.user_paused = false
	Ysdk.apply_pause()
	Ysdk.gameplay(true)


func _show_pause_page(p: String) -> void:
	pause_page = p
	if p == "pause":
		pause_ui.set_items("Пауза", [
			{"t": "text", "label": "День %d" % dn.day},
			{"t": "btn", "id": "resume", "label": "Продолжить", "accent": true}] + _coop_pause_items() + [
			{"t": "btn", "id": "settings", "label": "Настройки"},
			{"t": "btn", "id": "menu", "label": "В главное меню"}])
	else:
		pause_ui.set_items("Настройки", MenuUI.settings_items())


func _coop_pause_items() -> Array:
	if not Net.active or not Net.is_host:
		return []
	return [
		{"t": "btn", "id": "act_wood", "label": "Игра: гонка дров (90 с)"},
		{"t": "btn", "id": "act_axe", "label": "Игра: бой на топорах (90 с)"},
		{"t": "btn", "id": "act_race", "label": "Игра: гонка по городу (90 с)"},
		{"t": "btn", "id": "act_cash", "label": "Игра: денежная гонка (90 с)"},
		{"t": "btn", "id": "pvp_toggle", "label": "PvP (драки): " + ("выключить" if Net.pvp else "включить")}]


func _on_pause_action(id: String, value: Variant) -> void:
	if not pause_ui.visible:
		if id == "back":
			_pause_game()
		return
	if MenuUI.apply_setting(id, value):
		return
	match id:
		"resume":
			_resume_game()
		"act_wood":
			Net.start_activity("wood")
			_resume_game()
		"act_axe":
			Net.start_activity("axe")
			_resume_game()
		"act_race":
			Net.start_activity("race")
			_resume_game()
		"act_cash":
			Net.start_activity("cash")
			_resume_game()
		"pvp_toggle":
			Net.set_pvp(not Net.pvp)
			_resume_game()
		"settings":
			_show_pause_page("settings")
		"back":
			if pause_page == "settings":
				_show_pause_page("pause")
			else:
				_resume_game()
		"menu":
			_save_all()
			if Net.active:
				Net.leave()
			pause_ui.visible = false
			Ysdk.user_paused = false
			Ysdk.apply_pause()
			get_tree().change_scene_to_file("res://menu.tscn")


func _build_atmo() -> void:
	cloud_mat = StandardMaterial3D.new()
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.albedo_color = Color(1, 1, 1, 0.92)
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloud_mat.disable_fog = true
	clouds = Node3D.new()
	add_child(clouds)
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 10
	sm.rings = 5
	var crng := RandomNumberGenerator.new()
	crng.seed = 5
	for i in 11:
		var a := crng.randf() * TAU
		var r := crng.randf_range(70.0, 120.0)
		var cl := Node3D.new()
		cl.position = Vector3(cos(a) * r, crng.randf_range(48.0, 66.0), sin(a) * r)
		for k in crng.randi_range(3, 5):
			var mi := MeshInstance3D.new()
			mi.mesh = sm
			mi.material_override = cloud_mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3(k * 7.0 - 12.0, crng.randf_range(-1.0, 2.0), crng.randf_range(-3.0, 3.0))
			mi.scale = Vector3(crng.randf_range(7.0, 11.0), crng.randf_range(2.2, 3.4), crng.randf_range(4.0, 6.0))
			cl.add_child(mi)
		clouds.add_child(cl)
	player_light = OmniLight3D.new()
	player_light.position = Vector3(0, 2.2, 0.6)
	player_light.light_color = Color("ffd9a0")
	player_light.light_energy = 0.9
	player_light.omni_range = 8.0
	player_light.visible = false
	player.add_child(player_light)
	# светлячки
	var fm := SphereMesh.new()
	fm.radius = 0.07
	fm.height = 0.14
	fm.radial_segments = 6
	fm.rings = 3
	var fmat := MeshKit.glow_mat(Color("d8ff6a"), 3.0)
	for i in 26:
		var mi := MeshInstance3D.new()
		mi.mesh = fm
		mi.material_override = fmat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		flies.append(mi)


func _update_atmo(delta: float) -> void:
	atmo_t += delta
	var dk := dn.darkness
	var glow := clampf(dk * 2.2 - 0.2, 0.0, 1.0)
	for wm in WorldBuilder.win_mats:
		if not is_instance_valid(wm):
			continue
		var m := wm as StandardMaterial3D
		m.emission_energy_multiplier = glow * 2.6
		m.albedo_color = Color("2a3a4a").lerp(Color("ffd890"), glow)
	for pl in WorldBuilder.porch_lights:
		if is_instance_valid(pl):
			(pl as OmniLight3D).visible = glow > 0.35
	player_light.visible = glow > 0.2 and not in_club and in_house == ""
	player_light.light_energy = 0.9 * glow
	if in_club or in_house != "":
		return
	var pp := player.global_position
	clouds.position = Vector3(pp.x, 0.0, pp.z)
	clouds.rotation.y = atmo_t * 0.004
	cloud_mat.albedo_color = Color(1, 1, 1, 0.92).lerp(Color(0.12, 0.15, 0.3, 0.55), dk)
	var show_flies := dk > 0.6 and Settings.quality >= 1 and not _wolves_near()
	for i in flies.size():
		var f := flies[i] as MeshInstance3D
		f.visible = show_flies
		if show_flies:
			var a := float(i) * 2.399 + atmo_t * (0.12 + 0.02 * (i % 5))
			var r := 4.0 + float((i * 7) % 18)
			f.global_position = Vector3(pp.x + cos(a) * r, 0.9 + 0.8 * sin(atmo_t * 0.9 + i) + float(i % 3) * 0.5, pp.z + sin(a) * r)


func _wolves_near() -> bool:
	return get_tree().get_nodes_in_group("wolves").size() > 4


func _build_houses() -> void:
	var defs := {
		"makar": [Loc.t("ДОМ МАКАРА"), Color("8fa476"), Color("5a4a3a"), 9.0, 7.0],
		"lyuda": [Loc.t("ДОМ ЛЮДЫ"), Color("d9a8bc"), Color("7a3a5a"), 9.0, 7.0],
		"bytovka": [Loc.t("БЫТОВКА"), Color("86a0b8"), Color("3a4a5a"), 6.5, 5.5],
		"shop": [Loc.t("МАГАЗИН"), Color("e0d2a8"), Color("2f6a8a"), 10.0, 6.5]}
	for id in defs:
		var d: Array = defs[id]
		var h := WorldBuilder.house(d[0], d[1], d[2], d[3], d[4])
		h.position = HOUSES[id]["pos"]
		h.rotation.y = deg_to_rad(float(HOUSES[id]["rot"]))
		world.add_child(h)
		houses_nodes[id] = h


func _house_off(id: String) -> Vector3:
	return Vector3(700.0 + HOUSE_ORDER.find(id) * 40.0, 0, 0)


func _house_xf(id: String, lx: float, lz: float) -> Vector3:
	var h: Dictionary = HOUSES[id]
	return Vector3(h["pos"]) + Vector3(lx, 0, lz).rotated(Vector3.UP, deg_to_rad(float(h["rot"])))


## точка перед дверью, у которой появляется кнопка «Войти»
func _house_door(id: String) -> Vector3:
	var h: Dictionary = HOUSES[id]
	return _house_xf(id, float(h["dx"]), float(h["d"]) / 2.0 + 0.9)


func _house_out(id: String) -> Vector3:
	var h: Dictionary = HOUSES[id]
	return _house_xf(id, float(h["dx"]), float(h["d"]) / 2.0 + 2.0) + Vector3(0, 0.05, 0)


func _house_dir(id: String) -> Vector3:
	return Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(float(HOUSES[id]["rot"])))


func _near_house() -> String:
	for id in HOUSE_ORDER:
		if player.global_position.distance_to(_house_door(id)) < 2.4:
			return id
	return ""


func _get_interior(id: String) -> Interior3D:
	if not interiors.has(id):
		var it := Interior3D.new()
		it.position = _house_off(id)
		add_child(it)
		it.setup(id)
		interiors[id] = it
	return interiors[id]


func _enter_house(id: String) -> void:
	var it := _get_interior(id)
	_transition(func():
		in_house = id
		sun.visible = false
		env.fog_enabled = false
		env.ambient_light_energy = 0.55
		env.ambient_light_color = Color("a08a6a")
		player.velocity = Vector3.ZERO
		player.global_position = it.global_position + it.spawn_pos()
		player.face = 0.0
		yaw = 0.0
		pitch = 0.4
		build_mode = false
		ui.build_mode = false
		Sfx.play("coin", 0.8))


func _exit_house() -> void:
	var id := in_house
	_transition(func():
		in_house = ""
		sun.visible = true
		env.fog_enabled = true
		player.velocity = Vector3.ZERO
		player.global_position = _house_out(id)
		var o := _house_dir(id)
		player.face = atan2(-o.x, -o.z)
		yaw = atan2(-o.x, -o.z)
		pitch = 0.38
		dn._apply())


func _house_actions() -> void:
	_update_marks()
	var it: Interior3D = interiors[in_house]
	var local := player.global_position - it.global_position
	var talk_npc: Npc3D = null
	for nid in npcs:
		var n: Npc3D = npcs[nid]
		if n.at_home and n.home == in_house and n.global_position.distance_to(player.global_position) < 3.2:
			talk_npc = n
			n.name_lbl.visible = true
			break
	var near_pt: Dictionary = {}
	for pt in it.points:
		if Vector3(pt["pos"]).distance_to(local) < float(pt["r"]):
			near_pt = pt
			break
	var leaving := it.in_exit(local)
	if leaving:
		ui.a_label = "Выйти"
	elif talk_npc != null:
		ui.a_label = "Говорить"
	elif not near_pt.is_empty():
		ui.a_label = String(near_pt["label"])
	else:
		ui.a_label = "Осмотреться"
	if not ui.a_pressed or transitioning:
		return
	if leaving:
		_exit_house()
	elif talk_npc != null:
		near_npc = talk_npc
		_npc_talk(talk_npc)
	elif not near_pt.is_empty():
		_house_point(String(near_pt["id"]))
	else:
		ui.toast(HOUSE_LOOK.get(in_house, "Уютно."), Color("ffe9a8"))


const HOUSE_LOOK := {
	"home": "Твоя дача. Пахнет дровами и борщом позапрошлой недели.",
	"shed": "Сарай. Здесь есть всё, кроме того, что нужно.",
	"makar": "Дом Макара. На стене портрет какого-то усатого мужика. Это не Макар.",
	"lyuda": "Дом Люды. Всё в кружевах. Даже кот.",
	"bytovka": "Бытовка Коли. Труб тут больше, чем людей в посёлке.",
	"shop": "Магазин. Цены — как в Москве, ассортимент — как в 1994."}


func _house_point(pid: String) -> void:
	match pid:
		"bed":
			if bed_cd > 0.0:
				ui.toast("Не спится. Подожди ещё %d сек." % ceili(bed_cd), Color("ff9a9a"))
			elif Game.hp >= Game.max_hp - 1.0:
				ui.toast("Ты и так бодр, как огурец.", Color("ffe9a8"))
			else:
				Game.hp = minf(Game.max_hp, Game.hp + 40.0)
				bed_cd = 45.0
				Sfx.play("coin")
				ui.toast("Вздремнул. Здоровье +40", Color("9aff9a"))
		"chest":
			var key := in_house + "_chest"
			if looted.has(key):
				ui.toast("Пусто. Только пауки и воспоминания.", Color("ffe9a8"))
			else:
				looted[key] = true
				var w := 3 + (absi(hash(key)) % 4)
				var st := 1 + (absi(hash(key + "s")) % 3)
				Game.add_wood(w)
				Game.add_stone(st)
				Sfx.play("coin")
				ui.toast("Нашёл в сундуке: брёвна +%d, камни +%d" % [w, st], Color("9aff9a"))
		"radio":
			mode = "dialog"
			ui.open_dialog("Радио", [RADIO[rng.randi() % RADIO.size()]], func(): mode = "play")
		"tv":
			mode = "dialog"
			ui.open_dialog("Телевизор", ["Шипит. На экране — снег. Но Коля уверяет, что это «Лебединое озеро»."], func(): mode = "play")
		"bench":
			mode = "dialog"
			ui.open_dialog("Верстак", ["На верстаке лежат гвозди, гайки и недопитый чай с прошлого лета.", "Топор у тебя и так хороший. А вот Пассату хорошо бы новую запаску."], func(): mode = "play")
		"pie":
			if pie_cd > 0.0:
				ui.toast("Ты уже съел один. Второй — только если очень надо.", Color("ffe9a8"))
			else:
				pie_cd = 25.0
				Game.hp = minf(Game.max_hp, Game.hp + 25.0)
				Sfx.play("coin")
				ui.toast("Пирожок с гречкой. Здоровье +25", Color("9aff9a"))
		"cat":
			Game.hp = minf(Game.max_hp, Game.hp + 5.0)
			Sfx.play("coin", 1.4)
			ui.toast("Мур-р-р. Кот одобряет. Здоровье +5", Color("ffb0d8"))
		"letter":
			var q := _quest()
			mode = "dialog"
			if not q.is_empty() and q["type"] == "clue" and Game.q_state == 1:
				q_reached = true
			ui.open_dialog("Смятое письмо", ["«Уважаемый Н. М.! Предложение по участку остаётся в силе до первых холодов. Цена вас приятно удивит.»", "«Если не поймёте по-хорошему, поймёте по-плохому. Лес у вас, как говорится, дикий. С уважением, А. Б.»", "«Б.» — это, похоже, не Баба Люда. Надо рассказать Макару."], func(): mode = "play")


func _shop_buy() -> void:
	var it: Array = SHOP_ITEMS[shop_i % SHOP_ITEMS.size()]
	var nm: String = it[0]
	var cost: int = it[1]
	var heal: int = it[2]
	mode = "dialog"
	if Game.hp >= Game.max_hp - 1.0:
		ui.open_dialog(Loc.t("Зинаида"), ["Здоровья у тебя — хоть отбавляй. Заходи, когда поцарапают."], func(): mode = "play")
		return
	if Game.wood < cost:
		ui.open_dialog(Loc.t("Зинаида"), ["%s — %d бр. У тебя меньше. Иди руби, Михалыч." % [nm, cost]], func(): mode = "play")
		return
	Game.spend(cost, 0)
	Game.hp = minf(Game.max_hp, Game.hp + float(heal))
	shop_i += 1
	Sfx.play("coin")
	ui.toast("Купил: %s. Здоровье +%d" % [nm, heal], Color("9aff9a"))
	ui.open_dialog(Loc.t("Зинаида"), ["%s — %d бр. Кушай на здоровье!" % [nm, cost]], func(): mode = "play")


## NPC: жители, которые ходят по маршрутам, вечером уходят домой, утром выходят
func _add_walker(id: String, nm: String, style: Dictionary, route: Array, home: String, spd: float = 1.5) -> Npc3D:
	var n := _mk_npc(id, nm, style, route[0], 0.0)
	n.route = route
	n.walk_speed = spd
	n.home = home
	npcs[id] = n
	return n


func _build_town_npcs() -> void:
	var mk: Npc3D = npcs["makar"]
	mk.route = [Vector3(-7, 0, 13), Vector3(0, 0, 12.5), Vector3(6, 0, 14.5), Vector3(0, 0, 9.5)]
	mk.home = "makar"
	mk.walk_speed = 1.2
	var kl: Npc3D = npcs["kolya"]
	kl.route = [Vector3(-74, 0, -50), Vector3(-69, 0, -46), Vector3(-62, 0, -45), Vector3(-70, 0, -47.5)]
	kl.home = "bytovka"
	var ly: Npc3D = npcs["lyuda"]
	ly.route = [Vector3(66, 0, 12), Vector3(63, 0, 6), Vector3(60, 0, 3), Vector3(64, 0, 15)]
	ly.home = "lyuda"
	ly.walk_speed = 1.1
	_add_walker("vitya", Loc.t("Витя-рыбак"), {"shirt": Color("4a6a3a"), "pants": Color("3a3a2a"), "hat": "cap",
		"hat_col": Color("6a7a3a"), "beard": true, "beard_col": Color("5a3a22"), "skin": Color("d9a578")},
		[Vector3(67, 0, 27), Vector3(66, 0, 32), Vector3(62, 0, 30), Vector3(65, 0, 25)], "lyuda", 1.0)
	_add_walker("petrovich", Loc.t("Сторож Петрович"), {"shirt": Color("3a4a6a"), "pants": Color("2a2a3a"), "hat": "cap",
		"hat_col": Color("1a1a2a"), "beard": true, "beard_col": Color("c0c0c0"), "skin": Color("e0b890")},
		[Vector3(-20, 0, 14), Vector3(20, 0, 14), Vector3(20, 0, -24), Vector3(-20, 0, -24)], "makar", 1.6)
	var zn := _mk_npc("zina", Loc.t("Зинаида"), {"shirt": Color("f2f2f2"), "pants": Color("2a5a8a"), "hat": "none",
		"skin": Color("e7b48a")}, Vector3.ZERO, 0.0)
	npcs["zina"] = zn
	zn.home = "shop"
	zn.perma_home = true
	zn.mark_lbl.visible = false


## в нужное время уводит жителей домой и выпускает обратно
func _update_npcs() -> void:
	for id in npcs:
		var n: Npc3D = npcs[id]
		if n.home == "" or (Npc3D.frozen and not n.perma_home):
			continue
		if n.perma_home:
			if not n.at_home:
				_send_home(n)
			continue
		if dn.is_night:
			if not n.at_home and not n.go_home:
				n.go_home = true
				n.home_target = _house_door(n.home)
			elif n.go_home and n.arrived_home:
				_send_home(n)
		elif n.at_home or n.go_home:
			_leave_home(n)


func _send_home(n: Npc3D) -> void:
	var it := _get_interior(n.home)
	var spots: Array = it.npc_spots
	var idx: int = (hash(n.id) % maxi(1, spots.size())) if not spots.is_empty() else 0
	var spot: Vector3 = spots[idx] if not spots.is_empty() else Vector3.ZERO
	if n.get_parent() != null:
		n.get_parent().remove_child(n)
	it.add_child(n)
	n.position = spot
	n.rotation.y = PI if not n.perma_home else 0.0
	n.base_yaw = n.rotation.y
	n.at_home = true
	n.go_home = false
	n.arrived_home = false


func _leave_home(n: Npc3D) -> void:
	if n.at_home:
		n.get_parent().remove_child(n)
		world.add_child(n)
		n.position = _house_out(n.home)
		n.position.y = 0.0
	n.at_home = false
	n.go_home = false
	n.arrived_home = false
	n.wait = 0.0


func _enter_club() -> void:
	_transition(func():
		in_club = true
		sun.visible = false
		env.fog_enabled = false
		env.ambient_light_energy = 0.4
		env.ambient_light_color = Color("5a4a7a")
		club.active = true
		player.velocity = Vector3.ZERO
		player.global_position = CLUB_OFF + Vector3(0, 0.05, 3.8)
		player.face = 0.0
		yaw = 0.0
		pitch = 0.42
		build_mode = false
		ui.build_mode = false
		Sfx.set_club(true)
		Sfx.play("cheer", 1.2)
		ui.toast("Добро пожаловать в «Диско Енот»!", Color("ff8ad8"))
		club.rain())


func _exit_club() -> void:
	_transition(func():
		in_club = false
		sun.visible = true
		env.fog_enabled = true
		club.active = false
		player.hum.dance = false
		dance_t = 0.0
		player.velocity = Vector3.ZERO
		player.global_position = CLUB_DOOR + Vector3(0, 0.05, 1.5)
		player.face = 0.0
		yaw = 0.0
		pitch = 0.38
		dn._apply()
		Sfx.set_club(false))


func _transition(mid: Callable) -> void:
	if transitioning:
		return
	transitioning = true
	var tw := create_tween()
	tw.tween_property(ui, "fade", 1.0, 0.22)
	tw.tween_callback(func():
		mid.call()
		cam_rig.global_position = player.global_position + Vector3(0, 1.6, 0))
	tw.tween_property(ui, "fade", 0.0, 0.25)
	tw.tween_callback(func(): transitioning = false)


func _club_actions() -> void:
	var pp := player.global_position
	var near_bar: bool = pp.distance_to(club.global_position + Vector3(-9.0, 0, -1.0)) < 3.4
	var near_exit: bool = pp.z > CLUB_OFF.z + 7.6 and absf(pp.x - CLUB_OFF.x) < 2.6
	var near_dj: bool = pp.distance_to(club.global_position + Vector3(0, 0, -6.0)) < 3.0
	_update_marks()
	var bz: Npc3D = npcs["borzov"]
	var near_bz: bool = pp.distance_to(bz.global_position) < 3.4
	bz.name_lbl.visible = near_bz
	if near_exit:
		ui.a_label = "Выйти"
	elif near_bz:
		ui.a_label = "Говорить"
	elif near_bar:
		ui.a_label = "Выпить"
	elif near_dj:
		ui.a_label = "Говорить"
	else:
		ui.a_label = "Танцевать"
	if not ui.a_pressed or transitioning:
		return
	if near_exit:
		_exit_club()
	elif near_bz:
		near_npc = bz
		_npc_talk(bz)
	elif near_bar:
		_bar_talk()
	elif near_dj:
		mode = "dialog"
		ui.open_dialog(Loc.t("Диджей Борис"), ["Эй, дачник! Эту песню я написал сам. Называется «Волки воют».", "Подойди к бару, возьми квасу — и на танцпол. Только не врежься в диско-шар."], func(): mode = "play")
	else:
		dance_t = 6.0
		player.hum.dance = true
		Sfx.play("cheer", 1.1)


func _bar_talk() -> void:
	if drunk >= 5.0:
		mode = "dialog"
		ui.open_dialog(Loc.t("Бармен Эдик"), ["Хватит, Михалыч, ты уже еле стоишь. Иди танцуй, пока не вырубило!"], func(): mode = "play")
		return
	if Game.wood < DRINK_COST:
		mode = "dialog"
		ui.open_dialog(Loc.t("Бармен Эдик"), ["Напиток стоит %d бревна. Бревно — наша валюта, дружище." % DRINK_COST], func(): mode = "play")
		return
	Game.spend(DRINK_COST, 0)
	var nm: String = DRINKS[drink_i % DRINKS.size()]
	drink_i += 1
	drunk = minf(5.0, drunk + 1.0)
	Sfx.play("cheer", 0.9)
	ui.toast("Выпил: %s. Голова кругом!" % nm, Color("ff9aff"))


func _quest() -> Dictionary:
	if Game.quest >= Quests.L.size():
		return {}
	return Quests.L[Game.quest]


func _quest_ok(q: Dictionary) -> bool:
	match q["type"]:
		"bring_wood": return Game.wood >= int(q["n"])
		"bring_stone": return Game.stone >= int(q["n"])
		"kills": return Game.kills - Game.q_base >= int(q["n"])
		"build": return structs_root.get_child_count() >= int(q["n"])
		"survive": return dn.day >= int(q["n"])
		"reach", "clue": return q_reached
		"fish": return Game.fish - Game.q_base >= int(q["n"])
		"boss": return Game.bosses - Game.q_base >= 1
	return true


func _quest_progress(q: Dictionary) -> String:
	match q["type"]:
		"bring_wood": return "брёвна %d / %d" % [mini(Game.wood, int(q["n"])), int(q["n"])]
		"bring_stone": return "камни %d / %d" % [mini(Game.stone, int(q["n"])), int(q["n"])]
		"kills": return "волков %d / %d" % [mini(Game.kills - Game.q_base, int(q["n"])), int(q["n"])]
		"build": return "построек %d / %d" % [mini(structs_root.get_child_count(), int(q["n"])), int(q["n"])]
		"survive": return "день %d / %d" % [mini(dn.day, int(q["n"])), int(q["n"])]
		"reach": return "доехать до вышки" if not q_reached else "вернись и расскажи"
		"clue": return "осмотри стол в доме Макара" if not q_reached else "вернись и расскажи"
		"fish": return "Рыбы: %d / %d" % [mini(Game.fish - Game.q_base, int(q["n"])), int(q["n"])]
		"boss": return "вожак ещё жив" if Game.bosses - Game.q_base < 1 else "вожак убит, иди в клуб"
	return ""


func _quest_objective() -> String:
	var q := _quest()
	if q.is_empty():
		return "Все задания выполнены! Продолжай выживать. День %d, убито волков: %d" % [dn.day, Game.kills]
	var who: String = Quests_name(String(q.get("to", q["giver"])))
	var wid := String(q.get("to", q["giver"]) if Game.q_state == 1 else q["giver"])
	if npcs.has(wid) and (npcs[wid] as Npc3D).at_home:
		who += " (сейчас дома)"
	if Game.q_state == 0:
		return "Новое задание: поговори с «%s»" % Quests_name(String(q["giver"]))
	if q["type"] == "visit":
		return "%s. Иди к: %s" % [q["title"], who]
	return "%s (%s). Сдать: %s" % [q["title"], _quest_progress(q), who]


func Quests_name(id: String) -> String:
	return npcs[id].display_name if npcs.has(id) else id


## Разговор с NPC: берёт или сдаёт квест, иначе шутит.
func _npc_talk(n: Npc3D) -> void:
	mode = "dialog"
	var q := _quest()
	var name_s := n.display_name
	if Game.stage >= 4 and not q.is_empty():
		if Game.q_state == 0 and q["giver"] == n.id:
			Game.q_state = 1
			Game.q_base = Game.fish if q["type"] == "fish" else (Game.bosses if q["type"] == "boss" else Game.kills)
			q_reached = false
			Game.save()
			ui.toast("Задание: " + String(q["title"]), Color("ffd23a"))
			Sfx.play("coin")
			ui.open_dialog(name_s, q["intro"], func(): mode = "play")
			return
		if Game.q_state == 1 and String(q.get("to", q["giver"])) == n.id:
			if _quest_ok(q):
				_quest_done(q, n)
				return
			ui.open_dialog(name_s, [String(q.get("remind", "Ещё не всё.")) + " (" + _quest_progress(q) + ")"], func(): mode = "play")
			return
	if n.id == "makar":
		_makar_talk()
	elif n.id == "zina":
		_shop_buy()
	else:
		var jokes := {
			"kolya": ["Станок гудит — значит, жизнь налаживается.", "Бревно — оно как человек: сперва толстое, потом тоньше."],
			"lyuda": ["Рыбка сама не коптится. Хотя кот пробовал.", "Волков не боюсь. У меня сковородка есть."],
			"vitya": ["Тсс! Рыба спугнётся. Я тут третий год сижу, пока ни одной. Но чую — сегодня будет.", "Раньше тут тишина была. А теперь то джип, то волки. Вот к чему всё идёт?"],
			"borzov": ["Я тут просто отдыхаю. Совершенно законно.", "Кто сказал «волки»? Какие волки? Не слышал."],
			"petrovich": ["Дежурю! Периметр держу. Правда, в том году забор украли. Но я же его сторожил — значит, не украли, а перенесли.", "Волки? Какие волки? Я ничего не видел, я спал. То есть бдел."]}
		ui.open_dialog(name_s, jokes.get(n.id, ["..."]), func(): mode = "play")


func _quest_done(q: Dictionary, n: Npc3D) -> void:
	if q["type"] == "bring_wood":
		Game.spend(int(q["n"]), 0)
	elif q["type"] == "bring_stone":
		Game.spend(0, int(q["n"]))
	var rw: Dictionary = q["rw"]
	var txt := "Награда:"
	if rw.has("wood"):
		Game.add_wood(int(rw["wood"]))
		txt += " брёвна +%d" % int(rw["wood"])
	if rw.has("stone"):
		Game.add_stone(int(rw["stone"]))
		txt += " камни +%d" % int(rw["stone"])
	Game.quest += 1
	Game.q_state = 0
	Game.save()
	Sfx.play("cheer")
	ui.toast("Задание выполнено! " + txt, Color("9aff9a"))
	if Game.quest >= Quests.L.size():
		ui.toast("СЮЖЕТ ПРОЙДЕН! Дача спасена. Выживай дальше!", Color("ffd23a"))
	var finish: Callable = func(): mode = "play"
	ui.open_dialog(n.display_name, q["done"], finish)


func _makar_talk() -> void:
	mode = "dialog"
	var lines: Array
	match Game.stage:
		0, 1:
			lines = ["Рубишь? Молодец. Десять брёвен — и костёр твой. Дерево рубится за три удара, камень за четыре.",
				"Сильно волков не бойся. Они трусливее моей тёщи. Хотя нет, тёща страшнее."]
		2:
			lines = ["Десять брёвен есть? Жми «Стройка», выбирай костёр и ставь рядом с домом. До ночи успеешь.",
				"И пару стенок поставь, не повредит."]
		3:
			lines = ["Ночь на дворе! Держись у огня и бей их топором. Крикни, если прижмут — они аж присядут."]
		_:
			lines = ["Живой! Каждый день волков всё больше, так что строй крепче.",
				"Шипы под забором — моя любимая вещь. Волк наступил — волк передумал.",
				"Убито волков: %d. Уважаю." % Game.kills]
	ui.open_dialog("Дед Макар", lines, func(): mode = "play")


func _on_cloud(d: Dictionary) -> void:
	if Game.apply_dict(d):
		for c in structs_root.get_children():
			c.queue_free()
		await get_tree().process_frame
		_restore_structs()
		dn.day = Game.day
		ui.toast("Прогресс загружен из облака", Color("9aff9a"))


func _on_night(day: int) -> void:
	Sfx.play("night")
	Sfx.play("howl")
	wave_total = mini(2 + 2 * day, 16)
	if Net.active:
		wave_total = mini(int(wave_total * (1.0 + 0.6 * (Net.players.size() - 1))), 26)
	wave_spawned = 0
	spawn_t = 3.0
	night_kills = 0
	var qq := _quest()
	boss_pending = day % 3 == 0 or (not qq.is_empty() and qq["type"] == "boss" and Game.q_state == 1)
	if boss_pending:
		ui.toast("Вожак стаи идёт на дачу!", Color("ff6a6a"))
	ui.toast("Наступила ночь! Волки идут на дачу!", Color("ff9a9a"))
	if Game.stage == 2:
		ui.toast("Костёр не построен — бегом строить!", Color("ffd23a"))
		Game.set_stage(3)
	elif Game.stage < 3:
		Game.set_stage(3)
	Game.save()


func _on_dawn(_day: int) -> void:
	Sfx.play("dawn")
	wave_total = 0
	for w in wolves_root.get_children():
		if w is Wolf3D:
			(w as Wolf3D).run_away()
	ui.toast("Рассвет. Волки убежали. Ночь пережита!", Color("9aff9a"))
	if Game.stage == 3:
		Game.set_stage(4)
	Game.best_day = maxi(Game.best_day, dn.day)
	_save_all()
	Ysdk.show_interstitial()


func _on_day(day: int) -> void:
	Game.day = day
	Game.best_day = maxi(Game.best_day, day)
	ui.toast("День %d" % day, Color("ffe08a"))


# ---------------- цикл ----------------

func _process(delta: float) -> void:
	var playing := mode == "play" or mode == "car" or mode == "fish"
	var indoors := in_club or in_house != ""
	wolves_root.process_mode = Node.PROCESS_MODE_INHERIT if (playing and not indoors) else Node.PROCESS_MODE_DISABLED
	bed_cd = maxf(0.0, bed_cd - delta)
	pie_cd = maxf(0.0, pie_cd - delta)
	_update_npcs()
	_update_atmo(delta)
	if ui.pause_tapped:
		ui.pause_tapped = false
		_pause_game()
	drunk_t += delta
	drunk = maxf(0.0, drunk - delta * 0.04)
	if mode == "dialog" and not ui.dlg_active:
		mode = "play"
	if playing:
		if not indoors:
			dn.advance(delta)
			Sfx.set_music(dn.darkness)
		_update_camera_look(delta)
		_update_game(delta)
		_update_buddy(delta, indoors)
	else:
		buddy.idle(delta)
		buddy2.idle(delta)
		_update_camera_look(delta)
		if mode == "dead" and ui.modal_btn != "":
			_on_modal_choice(ui.modal_btn)
		player.idle(delta)
	_follow_camera(delta)
	_update_ui(delta)
	_perf_governor(delta)
	ui.a_pressed = false
	ui.b_pressed = false
	ui.c_pressed = false
	ui.w_pressed = false
	ui.sw_pressed = false
	ui.sp_pressed = false
	ui.cm_pressed = false
	ui.slot_tapped = -1


func _update_camera_look(_delta: float) -> void:
	var l := ui.take_look()
	yaw -= l.x * 0.0055 + sin(drunk_t * 0.45) * 0.0025 * minf(drunk, 5.0) * 0.6
	pitch = clampf(pitch + l.y * 0.0045, 0.05, 1.2)


func _follow_camera(delta: float) -> void:
	var tgt: Vector3 = (car.global_position + Vector3(0, 1.6, 0)) if mode == "car" else (player.global_position + Vector3(0, 1.6, 0))
	cam_rig.global_position = cam_rig.global_position.lerp(tgt, clampf(14.0 * delta, 0.0, 1.0))
	cam_rig.rotation = Vector3(-pitch, yaw, 0.0)
	var dkc := minf(drunk, 5.0) / 5.0
	shake_t = maxf(0.0, shake_t - delta)
	cam.h_offset = cam_off + sin(Time.get_ticks_msec() * 0.07) * shake_t * 0.5
	cam.v_offset = 0.15 + cos(Time.get_ticks_msec() * 0.09) * shake_t * 0.35
	cam.rotation.z = sin(drunk_t * 1.1) * 0.07 * dkc
	cam.fov = cam_fov + sin(drunk_t * 0.7) * 5.0 * dkc
	var sp_len := 7.6 if mode == "car" else (4.6 if not (in_club or in_house != "") else 4.0)
	spring.spring_length = lerpf(spring.spring_length, sp_len, clampf(4.0 * delta, 0.0, 1.0))
	# через плечо и лёгкий «наезд» на скорости, как в большой игре
	var spd := player.cur_speed if mode != "car" else absf(car.speed) * 0.4
	cam_off = lerpf(cam_off, 0.0 if mode == "car" else 0.55, clampf(3.0 * delta, 0.0, 1.0))
	cam_fov = lerpf(cam_fov, 66.0 + clampf((spd - 4.0) * 1.6, 0.0, 8.0), clampf(4.0 * delta, 0.0, 1.0))


func _update_game(delta: float) -> void:
	shout_cd = maxf(0.0, shout_cd - delta)
	var m := ui.get_move()
	var raw_move := m.length()
	if drunk > 0.05:
		var dk := minf(drunk, 5.0) / 5.0
		m += Vector2(sin(drunk_t * 2.1) * 0.55, cos(drunk_t * 1.7) * 0.35) * dk * (1.0 if m.length() > 0.1 else 0.45)
		m = m.limit_length(1.0)
	if dance_t > 0.0:
		dance_t -= delta
		if raw_move > 0.2 or dance_t <= 0.0:
			dance_t = 0.0
			player.hum.dance = false
	if in_club:
		player.walk(Vector3(m.x, 0.0, m.y).rotated(Vector3.UP, yaw) * (0.0 if dance_t > 0.0 else 1.0), delta)
		_club_actions()
		if drunk > 0.05:
			player.hum.rotation.z = sin(drunk_t * 1.9) * 0.1 * minf(drunk, 5.0)
		_update_regen(delta)
		return
	if in_house != "":
		player.walk(Vector3(m.x, 0.0, m.y).rotated(Vector3.UP, yaw), delta)
		_house_actions()
		if drunk > 0.05:
			player.hum.rotation.z = sin(drunk_t * 1.9) * 0.1 * minf(drunk, 5.0)
		_update_regen(delta)
		return
	fish_cd = maxf(0.0, fish_cd - delta)
	if mode == "fish":
		_update_fish(delta, m)
	elif mode == "car":
		_update_car(delta, m)
	else:
		var dir := Vector3(m.x, 0.0, m.y).rotated(Vector3.UP, yaw)
		if m.length() > 0.12:
			player.walk(dir, delta)
		else:
			player.walk(Vector3.ZERO, delta)
		_player_actions()
	if drunk > 0.05:
		player.hum.rotation.z = sin(drunk_t * 1.9) * 0.1 * minf(drunk, 5.0)
	_update_build()
	_update_wolves(delta)
	_update_regen(delta)
	if Game.stage < 2 and Game.wood >= Game.WOOD_GOAL:
		Game.set_stage(2)
		ui.toast("Хватит брёвен! Построй костёр: кнопка «Стройка»", Color("ffd23a"))
	elif Game.stage == 0 and Game.wood > 4:
		Game.stage = 1
	if Game.hp <= 0.0:
		_die()
	save_t += delta
	if save_t > 20.0:
		save_t = 0.0
		_save_all()


func _npc_mark(id: String) -> bool:
	var q := _quest()
	if id == "makar" and (Game.stage < 2 or not Game.intro_done):
		return true
	if Game.stage >= 4 and not q.is_empty():
		if Game.q_state == 0 and q["giver"] == id:
			return true
		if Game.q_state == 1 and String(q.get("to", q["giver"])) == id and _quest_ok(q):
			return true
	return false


func _update_marks() -> void:
	for id in npcs:
		(npcs[id] as Npc3D).mark_lbl.visible = _npc_mark(id)


func _player_actions() -> void:
	near_npc = null
	for id in npcs:
		var nn: Npc3D = npcs[id]
		var close := player.global_position.distance_to(nn.global_position) < 3.6
		nn.name_lbl.visible = close
		if close and near_npc == null:
			near_npc = nn
			nn.rotation.y = lerp_angle(nn.rotation.y, atan2(-(player.global_position.x - nn.global_position.x),
				-(player.global_position.z - nn.global_position.z)) + PI, 0.1)
		nn.mark_lbl.visible = _npc_mark(id)
	var near_fish := near_npc == null and player.global_position.distance_to(FISH_SPOT) < 3.5 and fish_cd <= 0.0
	var near_door := near_npc == null and player.global_position.distance_to(CLUB_DOOR) < 3.4
	var hid := "" if near_npc != null else _near_house()
	var near_makar := near_npc != null
	var best_car: Car3D = car
	for cc in cars:
		if (cc as Node3D).global_position.distance_to(player.global_position) < best_car.global_position.distance_to(player.global_position):
			best_car = cc
	car = best_car
	var near_car := player.global_position.distance_to(car.global_position) < 4.6
	var jack: Car3D = null if near_car else _near_jack()
	var city_lbl: String = "" if near_npc != null else city.near_label(player.global_position)
	var q2 := _quest()
	if Game.q_state == 1 and not q2.is_empty() and q2["type"] == "reach":
		if player.global_position.distance_to(q2["pos"]) < float(q2["r"]) or (mode == "car" and car.global_position.distance_to(q2["pos"]) < float(q2["r"])):
			if not q_reached:
				q_reached = true
				ui.toast("Ты у вышки! Волчьих следов тут полно. Возвращайся.", Color("ffd23a"))
	if ui.w_pressed:
		weapons.cycle()
	if ui.j_pressed:
		ui.j_pressed = false
		if mode == "play":
			player.jump()
	if ui.sw_pressed:
		_switch_char()
	if ui.wheel_pick >= 0:
		var pk: int = ui.wheel_pick
		ui.wheel_pick = -1
		_switch_char(pk)
	if ui.cm_pressed:
		ui.toast(_cn(buddy.char_id) + ": " + Loc.t(BuddyAI.MODES[(buddy_ai.mode + 1) % 4]), Color("9be0ff"))
		buddy_ai.cycle_mode()
		buddy2_ai.mode = buddy_ai.mode
	if ui.sp_pressed:
		if not player.special():
			ui.toast("Спец-приём ещё не готов (бей врагов и руби)", Color("c9c9c9"))
	if ui.c_pressed:
		_toggle_build()
	if ui.b_pressed and shout_cd <= 0.0:
		_shout()
	if build_mode:
		ui.a_label = "Поставить" if hot_sel < 4 else "Убрать"
	elif near_makar:
		ui.a_label = "Говорить"
	elif near_door or hid != "":
		ui.a_label = "Войти"
	elif near_fish:
		ui.a_label = "Рыбачить"
	elif city_lbl != "":
		ui.a_label = city_lbl
	elif near_car:
		ui.a_label = "В машину"
	elif jack != null:
		ui.a_label = "Угнать"
	else:
		ui.a_label = "Огонь" if (weapons.cur == 1 or weapons.cur == 2) else ("Удар" if player.fists() else "Топор")
	if build_mode:
		if ui.a_pressed:
			if hot_sel < 4:
				_place()
			else:
				_remove_near()
		return
	if hid != "" and not near_door and ui.a_pressed:
		_enter_house(hid)
	elif near_door and ui.a_pressed:
		_enter_club()
	elif near_fish and ui.a_pressed:
		_start_fish()
	elif city_lbl != "" and ui.a_pressed:
		city.interact(player.global_position)
	elif near_makar and ui.a_pressed:
		_npc_talk(near_npc)
	elif near_car and ui.a_pressed:
		_enter_car()
	elif jack != null and ui.a_pressed and city_lbl == "" and not near_makar:
		_carjack(jack)
	elif (ui.a_pressed or ui.is_a_held()) and not player.swinging() and not near_makar and city_lbl == "" and not near_car and not near_fish and not near_door and hid == "":
		if weapons.cur == 1 or weapons.cur == 2:
			weapons.try_fire()
		else:
			player.swing()
			Sfx.play("chop", 1.3 if weapons.cur == 0 and player.char_id == 0 else 2.0)


func _start_fish() -> void:
	mode = "fish"
	ui.fish_on = true
	ui.fish_left = 3
	ui.fish_caught = 0
	ui.fish_pos = 0.0
	fish_dir = 1.0
	fish_speed = 0.8
	_new_zone()
	player.face = atan2(-(98.0 - player.global_position.x), -(12.0 - player.global_position.z))


func _new_zone() -> void:
	var c := rng.randf_range(0.2, 0.8)
	ui.fish_zone = Vector2(c - 0.09, c + 0.09)


func _update_fish(delta: float, m: Vector2) -> void:
	player.idle(delta)
	ui.a_label = "Подсечь"
	ui.fish_pos += fish_dir * fish_speed * delta
	if ui.fish_pos > 1.0:
		ui.fish_pos = 1.0
		fish_dir = -1.0
	elif ui.fish_pos < 0.0:
		ui.fish_pos = 0.0
		fish_dir = 1.0
	var leave := m.length() > 0.6 or ui.b_pressed or Game.hp < 99.0 and _wolf_near(10.0)
	if ui.a_pressed:
		ui.fish_left -= 1
		if ui.fish_pos >= ui.fish_zone.x and ui.fish_pos <= ui.fish_zone.y:
			ui.fish_caught += 1
			Game.fish += 1
			Game.hp = minf(Game.max_hp, Game.hp + 20.0)
			Game.add_wood(1)
			Sfx.play("coin")
			ui.toast("Поймал рыбу! Здоровье +20", Color("9aff9a"))
		else:
			Sfx.play("hit", 0.7)
			ui.toast("Сорвалась!", Color("ff9a9a"))
		fish_speed += 0.25
		_new_zone()
	if ui.fish_left <= 0 or leave:
		ui.fish_on = false
		mode = "play"
		fish_cd = 45.0


func _wolf_near(r: float) -> bool:
	for w in get_tree().get_nodes_in_group("wolves"):
		if not (w as Wolf3D).dead and (w as Wolf3D).global_position.distance_to(player.global_position) < r:
			return true
	return false


func _shout() -> void:
	shout_cd = 10.0
	Sfx.play("shout")
	ui.toast("АААААА!", Color("9ac8ff"))
	for w in get_tree().get_nodes_in_group("wolves"):
		var wf := w as Wolf3D
		if wf.dead:
			continue
		if wf.global_position.distance_to(player.global_position) < 13.0:
			wf.stun_t = 3.0
			wf.knock = (wf.global_position - player.global_position).normalized() * 9.0


func _on_chop_hit() -> void:
	var fwd := Vector3(-sin(player.face), 0.0, -cos(player.face))
	var ppos := player.global_position
	var mul := player.swing_mul()
	# ударил напарника — он обижается и дерётся в ответ
	for bd in [buddy, buddy2]:
		var tb: Vector3 = bd.global_position - ppos
		tb.y = 0.0
		if bd.visible and tb.length() < 2.4 and tb.normalized().dot(fwd) > 0.0 and weapons.cur != 1 and weapons.cur != 2:
			bd.hurt((14.0 if player.fists() else 10.0) * mul, ppos, 6.0 + (6.0 if player.combo == 2 and player.fists() else 0.0))
			if bd.anger <= 0.0:
				ui.toast(_cn(bd.char_id) + " " + Loc.t("разозлился! Он дерётся в ответ."), Color("ff8a8a"))
			bd.anger = 14.0
			player.add_charge(0.06)
			Sfx.play("hit", 1.0)
			return
	if player.fists():
		# кулаки и ноги: деревья не рубят, но прохожим, милиции и волкам достаётся
		if city.hit_ped(ppos, fwd, 14.0 * mul, 12.0 * mul):
			Sfx.play("hurt", 1.3)
			player.add_charge(0.08)
			return
		for w in get_tree().get_nodes_in_group("wolves"):
			var wf2 := w as Wolf3D
			if wf2 != null and not wf2.dead:
				var d2 := wf2.global_position - ppos
				d2.y = 0.0
				if d2.length() < 2.4 and d2.normalized().dot(fwd) > 0.0:
					wf2.hurt(5.0 * mul, ppos, 5.0 + (6.0 if player.combo == 2 else 0.0))
					player.add_charge(0.07)
					return
		return
	if Net.active and fun != null and fun.on_chop(ppos, fwd):
		return
	if city.hit_ped(ppos, fwd):
		player.add_charge(0.08)
		return
	var best: Wolf3D = null
	var bd := 2.8
	for w in get_tree().get_nodes_in_group("wolves"):
		var wf := w as Wolf3D
		if wf.dead:
			continue
		var d := wf.global_position - ppos
		d.y = 0.0
		if d.length() < bd and d.normalized().dot(fwd) > 0.1:
			bd = d.length()
			best = wf
	if best != null:
		best.hurt(15.0, ppos, 8.0)
		player.add_charge(0.07)
		return
	var res := forest.hit_at(ppos + fwd * 1.3, 1.9, ppos)
	if res.is_empty():
		return
	player.add_charge(0.05)
	if Net.active:
		Net.send_hit(int(res["i"]), ppos)
	if res["felled"]:
		if res["kind"] == "tree":
			if Net.active and fun != null:
				fun.on_wood()
			Game.add_wood(3)
			ui.toast("+3 бревна", Color("e8b878"))
			Sfx.play("fell")
		else:
			Game.add_stone(2)
			ui.toast("+2 камня", Color("d8dce4"))
			Sfx.play("fell", 1.4)
	else:
		Sfx.play("chop", 0.9)


# ---------------- машина ----------------

func _enter_car(jack: bool = false) -> void:
	mode = "car"
	car.occupied = true
	car.speed = 0.0
	build_mode = false
	ui.build_mode = false
	_update_ghost_visible()
	ui.a_label = "Выйти"
	Sfx.play("engine")
	car_seq = "jack" if jack else "in"
	seq_t = 0.0
	seq_from = player.global_position
	if jack:
		_spawn_driver()
	player.velocity = Vector3.ZERO
	player.get_node("Col").set_deferred("disabled", true)
	var cname: String = {"passat": "Пассат", "uaz": "Буханка УАЗ", "sport": "Спорткар", "police": "Милицейская"}.get(car.kind, "Машина")
	ui.toast("%s! Стик: газ и руль. Давит волков." % cname, Color("ffd23a"))
	city.on_enter_car(car)


func _exit_car() -> void:
	car.speed = 0.0
	car.set_lights(false)
	player.visible = true
	car_seq = "out"
	seq_t = 0.0
	player.get_node("Col").set_deferred("disabled", true)
	player.global_position = car.to_global(Vector3(-0.42, 0.0, -0.1))
	player.velocity = Vector3.ZERO
	player.face = car.global_rotation.y
	(player.hum as HeroRig).seat = 1.0


func _car_seq(delta: float) -> void:
	seq_t += delta
	var h := player.hum as HeroRig
	var cb := car.global_transform.basis
	var door_p := car.to_global(Vector3(-1.5, 0.0, -0.25))
	var seat_p := car.to_global(Vector3(-0.42, 0.0, -0.1))
	var to_car := Vector3(cb.x.x, 0.0, cb.x.z).normalized()
	h.air = false
	if car_seq == "jack":
		_jack_seq(delta, door_p, seat_p, to_car)
		return
	if car_seq == "in":
		if seq_t < 0.5:
			var k := smoothstep(0.0, 1.0, seq_t / 0.5)
			player.global_position = seq_from.lerp(door_p, k)
			player.face = lerp_angle(player.face, atan2(-to_car.x, -to_car.z), clampf(14.0 * delta, 0.0, 1.0))
			player.hum.rotation.y = player.face
			car.door_open = clampf((seq_t - 0.1) / 0.35, 0.0, 1.0)
			h.swing_angle = NAN
			h.animate(delta, 3.0 * (1.0 - k) + 0.3)
		elif seq_t < 1.0:
			var k2 := smoothstep(0.0, 1.0, (seq_t - 0.5) / 0.5)
			player.global_position = door_p.lerp(seat_p, k2)
			h.seat = k2
			player.face = lerp_angle(player.face, car.global_rotation.y, clampf(10.0 * delta, 0.0, 1.0))
			player.hum.rotation.y = player.face
			h.animate(delta, 0.0)
		else:
			var k3 := clampf((seq_t - 1.0) / 0.25, 0.0, 1.0)
			car.door_open = 1.0 - k3
			h.animate(delta, 0.0)
			if k3 >= 1.0:
				car_seq = ""
				h.seat = 0.0
				player.set_active(false)
				Sfx.play("blip", 0.5)
	else:
		if seq_t < 0.2:
			car.door_open = clampf(seq_t / 0.2, 0.0, 1.0)
			h.animate(delta, 0.0)
		elif seq_t < 0.75:
			var k4 := smoothstep(0.0, 1.0, (seq_t - 0.2) / 0.55)
			player.global_position = seat_p.lerp(door_p - to_car * 0.2, k4)
			h.seat = 1.0 - k4
			player.face = lerp_angle(player.face, atan2(to_car.x, to_car.z), clampf(10.0 * delta, 0.0, 1.0))
			player.hum.rotation.y = player.face
			h.animate(delta, 0.0)
		else:
			var k5 := clampf((seq_t - 0.75) / 0.35, 0.0, 1.0)
			h.seat = 0.0
			player.global_position = door_p - to_car * (0.2 + k5 * 0.9)
			car.door_open = 1.0 - k5
			player.hum.rotation.y = player.face
			h.animate(delta, 2.5)
			if k5 >= 1.0:
				car_seq = ""
				mode = "play"
				car.occupied = false
				player.velocity = Vector3.ZERO
				player.set_active(true)


func _update_car(delta: float, m: Vector2) -> void:
	if car_seq != "":
		_car_seq(delta)
		return
	car.drive(-m.y, m.x, delta)
	city.car_update(car, delta)
	car.set_lights(dn.darkness > 0.3)
	ui.a_label = "Выйти"
	if ui.a_pressed and absf(car.speed) < 4.0:
		_exit_car()
		return
	if absf(car.speed) > 6.0:
		for w in get_tree().get_nodes_in_group("wolves"):
			var wf := w as Wolf3D
			if not wf.dead and wf.global_position.distance_to(car.global_position) < 2.8:
				wf.hurt(80.0, car.global_position, 12.0)
				car.shake_t = 0.25
	if Net.active and fun != null:
		fun.car_hit(car)
	player.global_position = car.global_position
	player.hum.animate(delta, 0.0)


# ---------------- стройка ----------------

func _toggle_build() -> void:
	build_mode = not build_mode
	ui.build_mode = build_mode
	ui.c_label = "Готово" if build_mode else "Стройка"
	if build_mode:
		ui.toast("Режим стройки: выбери слот, A — поставить", Color("9aff9a"))
	_update_ghost_visible()


func _update_ghost_visible() -> void:
	if ghost != null:
		ghost.visible = build_mode and hot_sel < 4


func _set_ghost(kind: String) -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
	ghost_kind = kind
	if kind == "":
		return
	ghost = Structure3D.make_visual(kind)
	add_child(ghost)
	for c in ghost.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_overlay = ghost_mat


func _update_build() -> void:
	ui.hotbar = _hotbar_data()
	if ui.slot_tapped >= 0:
		if ui.slot_tapped == hot_sel and hot_sel < 4:
			rot_extra = (rot_extra + 1) % 2
			ui.toast("Повёрнуто", Color.WHITE)
		hot_sel = ui.slot_tapped
	ui.hot_sel = hot_sel
	if not build_mode or hot_sel >= 4:
		if ghost != null:
			ghost.visible = false
		return
	var want: String = Structure3D.ORDER[hot_sel]
	if want != ghost_kind:
		_set_ghost(want)
	var fwd := Vector3(-sin(player.face), 0.0, -cos(player.face))
	var p := player.global_position + fwd * 4.0
	ghost_pos = Vector3(roundf(p.x), 0.0, roundf(p.z))
	ghost_rot = (int(roundf(player.face / (PI / 2.0))) + rot_extra + 400) % 4
	ghost.visible = true
	ghost.position = ghost_pos
	ghost.rotation.y = ghost_rot * PI / 2.0
	ghost_ok = _can_place(want)
	ghost_mat.albedo_color = Color(0.2, 1.0, 0.3, 0.42) if ghost_ok else Color(1.0, 0.2, 0.15, 0.45)


func _can_place(kind: String) -> bool:
	if structs_root.get_child_count() >= MAX_STRUCTS:
		return false
	if absf(ghost_pos.x) > HALF - 6.0 or absf(ghost_pos.z) > HALF - 6.0:
		return false
	if Vector2(ghost_pos.x - DachaBuilder.LAKE_C.x, ghost_pos.z - DachaBuilder.LAKE_C.z).length() < DachaBuilder.LAKE_R + 1.0:
		return false
	var d2 := Vector2(ghost_pos.x - player.global_position.x, ghost_pos.z - player.global_position.z).length()
	if d2 < 1.8:
		return false
	var info: Dictionary = Structure3D.CAT[kind]
	var size: Vector3 = info["size"]
	var shape := BoxShape3D.new()
	shape.size = Vector3(size.x - 0.1, maxf(0.2, size.y - 0.5), size.z - 0.1)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = 1
	var xf := Transform3D(Basis(Vector3.UP, ghost_rot * PI / 2.0), Vector3(ghost_pos.x, 0.3 + shape.size.y / 2.0, ghost_pos.z))
	q.transform = xf
	q.exclude = [player.get_rid(), car.get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(q, 8)
	for h in hits:
		var c: Object = h["collider"]
		if c is Wolf3D:
			continue
		return false
	return true


func _place() -> void:
	var kind: String = Structure3D.ORDER[hot_sel]
	var info: Dictionary = Structure3D.CAT[kind]
	if not Game.can_afford(info["wood"], info["stone"]):
		ui.toast("Не хватает ресурсов", Color("ff8a8a"))
		return
	if not ghost_ok:
		ui.toast("Сюда нельзя ставить", Color("ff8a8a"))
		return
	Game.spend(info["wood"], info["stone"])
	_spawn_struct(kind, ghost_pos, ghost_rot)
	if Net.active:
		Net.send_build(kind, ghost_pos.x, ghost_pos.z, ghost_rot)
	Sfx.play("build")
	if kind == "fire" and Game.stage == 2:
		Game.set_stage(3 if dn.is_night else 2)
		ui.toast("Костёр горит! Теперь ждём ночь у огня.", Color("ffd23a"))
	_sync_structs()


func _spawn_struct(kind: String, pos: Vector3, rot: int) -> Structure3D:
	var s := Structure3D.new()
	s.position = pos
	structs_root.add_child(s)
	s.setup(kind, rot)
	s.destroyed.connect(_on_struct_destroyed)
	return s


func _on_struct_destroyed(_s: Structure3D) -> void:
	if Net.active and Net.is_host:
		Net.send_unbuild(_s.position.x, _s.position.z)
	Sfx.play("fell", 1.5)
	ui.toast("Постройку разгрызли!", Color("ff9a9a"))
	_sync_structs.call_deferred()


func _remove_near() -> void:
	var fwd := Vector3(-sin(player.face), 0.0, -cos(player.face))
	var p := player.global_position + fwd * 2.2
	var best: Structure3D = null
	var bd := 3.2
	for s in structs_root.get_children():
		var d := Vector2(s.global_position.x - p.x, s.global_position.z - p.z).length()
		if d < bd:
			bd = d
			best = s as Structure3D
	if best == null:
		ui.toast("Рядом нечего убирать", Color("ff8a8a"))
		return
	var info: Dictionary = Structure3D.CAT[best.kind]
	Game.add_wood(int(info["wood"]) / 2)
	Game.add_stone(int(info["stone"]) / 2)
	if Net.active:
		Net.send_unbuild(best.position.x, best.position.z)
	best.queue_free()
	Sfx.play("build", 0.7)
	_sync_structs.call_deferred()


func _sync_structs() -> void:
	var arr: Array = []
	for s in structs_root.get_children():
		if s.is_queued_for_deletion():
			continue
		var st := s as Structure3D
		arr.append({"k": st.kind, "x": st.position.x, "z": st.position.z, "r": st.rot_idx})
	Game.structures = arr


func _restore_structs() -> void:
	for d in Game.structures:
		_spawn_struct(String(d["k"]), Vector3(float(d["x"]), 0.0, float(d["z"])), int(d["r"]))


func _save_all() -> void:
	_sync_structs()
	Game.day = dn.day
	Game.save()


# ---------------- волки ----------------

func _update_wolves(delta: float) -> void:
	if Net.active and not Net.is_host:
		return
	var alive := 0
	var ppos: Vector3 = car.global_position if mode == "car" else player.global_position
	if Net.active:
		ppos = _net_pick_pos(ppos)
		_net_retarget(delta)
	for w in wolves_root.get_children():
		var wf := w as Wolf3D
		if wf == null or wf.dead:
			continue
		alive += 1
		if wf.flee and wf.global_position.distance_to(ppos) > 75.0:
			wf.die(false)
	if dn.is_night and wave_spawned < wave_total:
		spawn_t -= delta
		var active := 0
		for w in wolves_root.get_children():
			var wf2 := w as Wolf3D
			if wf2 != null and not wf2.dead and not wf2.flee:
				active += 1
		if spawn_t <= 0.0 and active < 8:
			spawn_t = 3.0
			for i in mini(3, wave_total - wave_spawned):
				_spawn_wolf(ppos)
	if not dn.is_night and wave_total == 0:
		for w in wolves_root.get_children():
			var wf3 := w as Wolf3D
			if wf3 != null and not wf3.dead and not wf3.flee:
				wf3.run_away()


func _spawn_wolf(ppos: Vector3) -> void:
	var a := rng.randf() * TAU
	var p := ppos + Vector3(cos(a), 0.0, sin(a)) * 46.0
	p.x = clampf(p.x, -HALF + 8.0, HALF - 8.0)
	p.z = clampf(p.z, -HALF + 8.0, HALF - 8.0)
	var w := Wolf3D.new()
	if boss_pending and wave_spawned >= wave_total - 1:
		w.kind = "boss"
		boss_pending = false
	elif dn.day >= 2 and rng.randf() < 0.25:
		w.kind = "pup"
	w.position = p
	wolves_root.add_child(w)
	w.target = player
	w.died.connect(_on_wolf_died)
	w.bit_player.connect(_on_wolf_bite.bind(w))
	wave_spawned += 1
	if wave_spawned % 3 == 1:
		Sfx.play("howl", rng.randf_range(0.85, 1.15))


func _on_wolf_bite(dmg: float, w: Wolf3D) -> void:
	if w.target is RemotePlayer:
		Net.send_bite((w.target as RemotePlayer).peer_id, dmg, w.global_position)
	else:
		player.hurt(dmg, w.global_position)


func _on_wolf_died(_w: Wolf3D) -> void:
	Game.cash += 5
	Game.kills += _w.kill_value
	if _w.kind == "boss":
		Game.bosses += 1
		ui.toast("Вожак Седой повержен!", Color("ffd23a"))
	night_kills += 1


func _update_regen(delta: float) -> void:
	if Game.hp <= 0.0 or Game.hp >= Game.max_hp:
		return
	var ppos := player.global_position
	for w in get_tree().get_nodes_in_group("wolves"):
		var wf := w as Wolf3D
		if not wf.dead and wf.global_position.distance_to(ppos) < 20.0:
			return
	Game.hp = minf(Game.max_hp, Game.hp + 1.5 * delta)


# ---------------- смерть и реклама ----------------

func _die() -> void:
	if mode == "dead" or mode == "ad":
		return
	if mode == "car":
		_exit_car()
	mode = "dead"
	build_mode = false
	ui.build_mode = false
	ui.c_label = "Стройка"
	_update_ghost_visible()
	ui.modal = "dead"
	ui.modal_btn = ""
	ui.modal_title = "Тебя съели волки!"
	ui.modal_sub = "Ты продержался до дня %d. Убито волков: %d" % [dn.day, Game.kills]
	player.hum.swing_angle = NAN
	Ysdk.gameplay(false)
	Sfx.play("howl", 0.8)
	if Net.active and fun != null:
		fun.on_died()


func _on_modal_choice(choice: String) -> void:
	ui.modal_btn = ""
	if choice == "ad" and Net.active:
		if fun != null and fun.dead_t < 12.0:
			return
		_respawn(true)
		Game.hp = 50.0
		player.global_position = SPAWN
	elif choice == "ad":
		mode = "ad"
		ui.modal = "ad"
		ui.modal_title = "Возрождение"
		ui.modal_sub = "Досмотри рекламу до конца"
		Ysdk.show_rewarded()
	else:
		_respawn(false)


func _on_ad_result(ok: bool) -> void:
	if mode != "ad":
		return
	if ok:
		_respawn(true)
	else:
		mode = "dead"
		ui.modal = "dead"
		ui.toast("Реклама не досмотрена — награды нет", Color("ff8a8a"))


func _respawn(by_ad: bool) -> void:
	city.clear_wanted(true)
	weapons.reset()
	ui.modal = ""
	mode = "play"
	Ysdk.gameplay(true)
	if by_ad:
		Game.hp = Game.max_hp
	else:
		Game.hp = 60.0
		Game.wood /= 2
		Game.stone /= 2
		Game.changed.emit()
		player.global_position = SPAWN
		player.velocity = Vector3.ZERO
	player.invuln = 3.0
	for w in wolves_root.get_children():
		var wf := w as Wolf3D
		if wf != null and not wf.dead and wf.global_position.distance_to(player.global_position) < 30.0:
			wf.die(false)
	ui.toast("Ты снова на ногах!", Color("9aff9a"))
	Game.save()


# ---------------- интерфейс ----------------

var perf_t := 0.0
var perf_level := 0
var perf_frames := 0


## Если кадров мало — понижаем разрешение 3D и тени (только вниз, чтобы не прыгало).
func _perf_governor(delta: float) -> void:
	if Time.get_ticks_msec() < 6000:
		return
	perf_t += delta
	perf_frames += 1
	if perf_t < 2.0:
		return
	var fps := perf_frames / perf_t
	perf_t = 0.0
	perf_frames = 0
	if fps < 48.0 and perf_level < 3 and not in_club:
		perf_level += 1
		match perf_level:
			1:
				get_viewport().scaling_3d_scale = minf(base_scale, 0.8)
				sun.directional_shadow_max_distance = 30.0
			2:
				get_viewport().scaling_3d_scale = minf(base_scale, 0.66)
				sun.shadow_enabled = false
			3:
				get_viewport().scaling_3d_scale = minf(base_scale, 0.5)
				cam.far = 120.0


var _wheel_slow := false


func _update_ui(_delta: float) -> void:
	# замедление времени, пока открыто колесо героев (не трогаем чужие «стоп-кадры»)
	if ui.wheel_open and not _wheel_slow:
		_wheel_slow = true
		Engine.time_scale = 0.2
	elif not ui.wheel_open and _wheel_slow:
		_wheel_slow = false
		Engine.time_scale = 1.0
	ui.drunk = drunk
	ui.cash = Game.cash
	ui.stars = city.stars
	ui.in_club = in_club
	ui.obj_override = _quest_objective() if Game.stage >= 4 else ""
	if mission != null and mission.active():
		ui.obj_override = mission.objective()
	ui.clock_day = dn.day
	ui.clock_frac = dn.cycle_frac()
	ui.clock_night = dn.is_night
	var left := int(dn.seconds_to_change())
	if dn.is_night:
		ui.clock_text = "до рассвета %d:%02d" % [left / 60, left % 60]
	else:
		ui.clock_text = "до ночи %d:%02d" % [left / 60, left % 60]
	var alive := get_tree().get_nodes_in_group("wolves").size()
	ui.wave_text = ("Волков рядом: %d" % alive) if dn.is_night and alive > 0 else ""
	ui.hurt_t = player.hurt_t
	if mode != "car":
		ui.b_label = "Орать" if shout_cd <= 0.0 else "%d" % ceili(shout_cd)
	else:
		ui.b_label = ""


## Служебное: сохраняет построенный кодом мир в res://world_view.tscn, чтобы его можно было смотреть в редакторе.
func _snapshot() -> void:
	await get_tree().create_timer(1.0).timeout
	var total := _set_owners(self, self)
	var cam_ed := Camera3D.new()
	cam_ed.name = "OverviewCamera"
	add_child(cam_ed)
	cam_ed.owner = self
	cam_ed.position = Vector3(26, 16, 34)
	cam_ed.look_at_from_position(cam_ed.position, Vector3(0, 2, -6))
	set_script(null)
	var ps := PackedScene.new()
	var r := ps.pack(self)
	print("SNAP pack=", r, " nodes=", total)
	print("SNAP save=", ResourceSaver.save(ps, "res://world_view.tscn"))
	get_tree().quit()


func _set_owners(n: Node, root: Node) -> int:
	var cnt := 0
	for c in n.get_children():
		if c is CanvasLayer or c is Wolf3D or c is Camera3D or c is SpringArm3D:
			continue
		c.owner = root
		cnt += 1 + _set_owners(c, root)
	return cnt


# ---------------- игра вместе ----------------

func _exit_tree() -> void:
	if Net.main == self:
		Net.detach()


func net_state() -> Array:
	var in_c := mode == "car"
	var pos: Vector3 = car.global_position if in_c else player.global_position
	var face: float = car.rotation.y if in_c else player.face
	var spd: float = car.speed if in_c else player.cur_speed
	var fl := 0
	if player.swinging():
		fl |= 1
	if in_c:
		fl |= 2
	if mode == "dead" or Game.hp <= 0.0:
		fl |= 4
	if player.hum.dance:
		fl |= 8
	if player.down_t > 0.0:
		fl |= 16
	if not in_c and not player.is_on_floor():
		fl |= 32
	return [pos, face, spd, fl]


func net_time(t: float, day: int) -> void:
	if in_club or in_house != "":
		return
	dn.sync_to(t, day)


func net_hit(idx: int, from: Vector3) -> void:
	var res := forest.hit_idx(idx, from)
	if res.is_empty():
		return
	if res["felled"]:
		Sfx.play("fell", 1.0 if res["kind"] == "tree" else 1.4)
	else:
		Sfx.play("chop", 0.9)


func net_build(kind: String, x: float, z: float, r: int) -> void:
	_spawn_struct(kind, Vector3(x, 0.0, z), r)
	_sync_structs.call_deferred()
	Sfx.play("build")


func net_unbuild(x: float, z: float) -> void:
	for s in structs_root.get_children():
		if s.is_queued_for_deletion():
			continue
		if Vector2(s.position.x - x, s.position.z - z).length() < 0.4:
			s.queue_free()
			Sfx.play("build", 0.7)
			break
	_sync_structs.call_deferred()


func net_toast(text: String) -> void:
	ui.toast(text, Color("9ad0ff"))


func net_pvp_hit(dmg: float, from: Vector3, push: float, lift: float, down: float, attacker: int) -> void:
	if mode in ["dead", "ad", "car"] or Game.hp <= 0.0:
		return
	player.invuln = 0.0
	player.hurt(dmg, from, push, lift, down)
	if fun != null:
		fun.got_hit(attacker)


func net_revive(by: int) -> void:
	if mode != "dead":
		return
	ui.modal = ""
	mode = "play"
	Ysdk.gameplay(true)
	Game.hp = 50.0
	player.invuln = 3.0
	ui.toast("Друг поднял тебя!", Color("9aff9a"))


func net_take_hit(dmg: float, from: Vector3) -> void:
	player.hurt(dmg, from)


func net_make_wolf(kind: int, pos: Vector3) -> Wolf3D:
	var w := Wolf3D.new()
	w.kind = ["wolf", "pup", "boss"][clampi(kind, 0, 2)]
	w.puppet = true
	w.position = pos
	wolves_root.add_child(w)
	w.net_pos = pos
	return w


func net_wolf_snapshot() -> PackedFloat32Array:
	var a := PackedFloat32Array()
	for w in wolves_root.get_children():
		var wf := w as Wolf3D
		if wf == null or wf.dead or wf.puppet:
			continue
		if wf.net_id == 0:
			wf.net_id = Net.next_wolf
			Net.next_wolf += 1
		var kc := 0
		if wf.kind == "pup":
			kc = 1
		elif wf.kind == "boss":
			kc = 2
		a.append_array(PackedFloat32Array([float(wf.net_id), float(kc), wf.global_position.x, wf.global_position.z, wf.rotation.y, 0.0]))
	return a


func net_wolf_hit(id: int, dmg: float, from: Vector3) -> void:
	for w in wolves_root.get_children():
		var wf := w as Wolf3D
		if wf != null and not wf.dead and wf.net_id == id:
			wf.hurt(dmg, from, 8.0)
			return


## Куда волкам идти: выбираем случайного живого игрока (хозяин и друзья).
func _net_pick_pos(fallback: Vector3) -> Vector3:
	var pts: Array = []
	if Game.hp > 0.0:
		pts.append(fallback)
	for id in Net.remotes:
		var rp := Net.remotes[id] as RemotePlayer
		if rp != null and not rp.dead and not rp.first:
			pts.append(rp.global_position)
	if pts.is_empty():
		return fallback
	return pts[rng.randi() % pts.size()]


var retarget_t := 0.0


func _net_retarget(delta: float) -> void:
	retarget_t -= delta
	if retarget_t > 0.0:
		return
	retarget_t = 0.4
	var cands: Array = []
	if Game.hp > 0.0 and in_house == "" and not in_club:
		cands.append(player)
	for id in Net.remotes:
		var rp := Net.remotes[id] as RemotePlayer
		if rp != null and not rp.dead and not rp.first:
			cands.append(rp)
	if cands.is_empty():
		return
	for w in wolves_root.get_children():
		var wf := w as Wolf3D
		if wf == null or wf.dead or wf.flee:
			continue
		var best: Node3D = null
		var bd := 1e9
		for c in cands:
			var d: float = (c as Node3D).global_position.distance_to(wf.global_position)
			if d < bd:
				bd = d
				best = c
		wf.target = best


# ---------------- напарник и смена героя ----------------

func _update_buddy(delta: float, indoors: bool) -> void:
	switch_cd = maxf(0.0, switch_cd - delta)
	ui.sw_label = "→ " + _cn(buddy.char_id)
	ui.cm_label = Loc.t(BuddyAI.MODES[buddy_ai.mode])
	ui.wheel_info = [
		{"id": player.char_id, "name": _cn(player.char_id), "hp": Game.hp, "cur": true},
		{"id": buddy.char_id, "name": _cn(buddy.char_id), "hp": buddy.bhp, "cur": false},
		{"id": buddy2.char_id, "name": _cn(buddy2.char_id), "hp": buddy2.bhp, "cur": false}]
	ui.sp_label = Loc.t("Вихрь" if player.char_id == 0 else "Ярость")
	ui.sp_charge = 1.0 if (player.spec_t >= 0.0 or player.rage_t > 0.0) else player.charge
	ui.sp_active = player.spec_t >= 0.0 or player.rage_t > 0.0
	# заряд спец-приёма понемногу копится сам
	player.add_charge(delta * 0.02)
	buddy.add_charge(delta * 0.02)
	buddy2.add_charge(delta * 0.02)
	if indoors:
		for bd in [buddy, buddy2]:
			if bd.visible:
				bd.set_active(false)
		return
	for k in 2:
		var bd: Player3D = buddy if k == 0 else buddy2
		var ai: BuddyAI = buddy_ai if k == 0 else buddy2_ai
		if not bd.visible:
			bd.set_active(true)
			ai._warp_near(player.global_position + Vector3(2.0 * (k * 2 - 1), 0, 1.5))
		if mode == "car" and car_seq == "":
			bd.idle(delta)
		else:
			ai.tick(delta)


func _body_state(p: Player3D, is_pl: bool) -> Dictionary:
	return {"pos": p.global_position, "face": p.face, "char": p.char_id, "w": weapons.cur if is_pl else p.weapon,
		"hp": Game.hp if is_pl else p.bhp, "ch": p.charge, "rage": p.rage_t}


func _put_state(p: Player3D, d: Dictionary, is_pl: bool) -> void:
	p.global_position = d["pos"]
	p.velocity = Vector3.ZERO
	p.face = d["face"]
	p.set_char(int(d["char"]))
	p.charge = d["ch"]
	p.rage_t = d["rage"]
	if is_pl:
		weapons.cur = int(d["w"])
		p.set_weapon(weapons.cur)
		Game.hp = clampf(float(d["hp"]), 1.0, 100.0)
	else:
		p.set_weapon(int(d["w"]))
		p.bhp = clampf(float(d["hp"]), 1.0, 100.0)
		p.anger = 0.0


## Все трое всегда на карте. Смена: ты переходишь в тело следующего героя (он остаётся там, где стоял),
## остальные двое сдвигаются по кругу: Михалыч → Тревор → Джейсон → Михалыч.
func _switch_char(target: int = -1) -> void:
	if mode != "play" or in_club or in_house != "" or build_mode or transitioning or switch_cd > 0.0:
		return
	if target == player.char_id:
		return
	if player.spec_t >= 0.0 or player.down_t > 0.0 or buddy.down_t > 0.0 or buddy2.down_t > 0.0:
		ui.toast("Сейчас не переключиться", Color("c9c9c9"))
		return
	switch_cd = 1.0
	_transition(func():
		var d0 := _body_state(player, true)
		var d1 := _body_state(buddy, false)
		var d2 := _body_state(buddy2, false)
		if target >= 0 and buddy2.char_id == target and buddy.char_id != target:
			_put_state(player, d2, true)
			_put_state(buddy2, d1, false)
			_put_state(buddy, d0, false)
		else:
			_put_state(player, d1, true)
			_put_state(buddy, d2, false)
			_put_state(buddy2, d0, false)
		spring.spring_length = 15.0
		Game.changed.emit()
		ui.toast(Loc.t("Ты —") + " " + _cn(player.char_id), Color("c9a6ff"))
		Sfx.play("blip", 1.4))


## Спец-приёмы обоих героев: «Лесной вихрь» (kind 0), «Ярость» — ударная волна (1), приземление в ярости (2).
func special_effect(who: Player3D, kind: int, is_player: bool) -> void:
	var pos := who.global_position
	var radius := 3.5
	var dmg := 22.0
	var push := 9.0
	if kind == 1:
		radius = 6.0
		dmg = 38.0
		push = 15.0
		shake_t = 0.5
		_ring_fx(pos, Color("ff5a2a"), 7.0)
		Sfx.play("fell", 0.6)
		if is_player:
			_slowmo(0.35, 0.28)
	elif kind == 2:
		radius = 3.6
		dmg = 20.0
		push = 9.0
		shake_t = 0.3
		_ring_fx(pos, Color("ff8a4a"), 4.5)
		Sfx.play("fell", 0.9)
	else:
		_ring_fx(pos + Vector3(0, 0.9, 0), Color("e8e8f0"), 3.4, true)
		Sfx.play("chop", 0.8)
	for w in get_tree().get_nodes_in_group("wolves"):
		var wf := w as Wolf3D
		if wf != null and not wf.dead and wf.global_position.distance_to(pos) < radius:
			wf.hurt(dmg, pos, push)
	for i in 6:
		var dir := Vector3.FORWARD.rotated(Vector3.UP, i * TAU / 6.0)
		city.hit_ped(pos, dir, dmg * 1.1, dmg * 1.2)
	if kind == 0:
		var res := forest.hit_at(pos, 3.0, pos)
		if not res.is_empty() and res["felled"]:
			if res["kind"] == "tree":
				Game.add_wood(3)
				ui.toast("+3 бревна", Color("e8b878"))
			else:
				Game.add_stone(2)
	# попал по напарнику / по игроку
	if is_player:
		for bd in [buddy, buddy2]:
			if bd.visible and bd.global_position.distance_to(pos) < radius:
				bd.hurt(dmg, pos, push, 3.0, 0.0)
				bd.anger = 14.0
				ui.toast(_cn(bd.char_id) + " " + Loc.t("разозлился!"), Color("ff8a8a"))
	elif player.visible and player.global_position.distance_to(pos) < radius:
		player.hurt(dmg * 0.4, pos, push, 3.0, 0.0)
	if kind == 1:
		who.add_charge(0.0)


func _ring_fx(pos: Vector3, col: Color, grow: float, vertical: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	mi.mesh = t
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.emission_enabled = true
	mt.emission = col
	mt.emission_energy_multiplier = 1.5
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mt
	add_child(mi)
	mi.global_position = pos + (Vector3.ZERO if vertical else Vector3(0, 0.12, 0))
	mi.scale = Vector3.ONE * 0.4
	var tw := create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * grow, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(mt, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)


func _slowmo(scale: float, secs: float) -> void:
	Engine.time_scale = scale
	get_tree().create_timer(secs, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _near_jack() -> Car3D:
	for tc in city.traffic:
		if is_instance_valid(tc) and (tc as Car3D).ai and (tc as Car3D).kind != "police" \
				and (tc as Node3D).global_position.distance_to(player.global_position) < 3.6:
			return tc
	return null


func _carjack(tc: Car3D) -> void:
	city.traffic.erase(tc)
	tc.ai = false
	tc.speed = 0.0
	if not cars.has(tc):
		cars.append(tc)
	car = tc
	city.add_heat(2.0, "УГОН!")
	ui.toast(Loc.t("Водитель вылетел из машины!"), Color("ff8a8a"))
	_enter_car(true)


func _cn(i: int) -> String:
	return Loc.t(CharDefs.NAMES[i])


var jack_driver: Humanoid

func _spawn_driver() -> void:
	if jack_driver != null and is_instance_valid(jack_driver):
		jack_driver.queue_free()
	jack_driver = Humanoid.new()
	jack_driver.setup({"shirt": Color.from_hsv(randf(), 0.5, 0.8), "pants": Color("3a3f55"), "hair": Color("2a2a2a")})
	add_child(jack_driver)
	jack_driver.global_position = car.to_global(Vector3(-0.42, -0.45, -0.1))
	jack_driver.rotation.y = car.global_rotation.y


func _jack_seq(delta: float, door_p: Vector3, seat_p: Vector3, to_car: Vector3) -> void:
	var h := player.hum as HeroRig
	var out_dir := -to_car
	var ground := door_p + out_dir * 0.2
	if seq_t < 0.45:
		# подбегает к двери
		var k := smoothstep(0.0, 1.0, seq_t / 0.45)
		player.global_position = seq_from.lerp(door_p, k)
		player.face = lerp_angle(player.face, atan2(-to_car.x, -to_car.z), clampf(14.0 * delta, 0.0, 1.0))
		player.hum.rotation.y = player.face
		car.door_open = clampf((seq_t - 0.05) / 0.35, 0.0, 1.0)
		h.animate(delta, 4.0 * (1.0 - k) + 0.5)
	elif seq_t < 0.9:
		# наклоняется в салон
		var k2 := smoothstep(0.0, 1.0, (seq_t - 0.45) / 0.45)
		player.global_position = door_p + to_car * 0.3 * k2
		h.lean_in = k2
		h.pull = 0.0
		player.hum.rotation.y = player.face
		h.animate(delta, 0.0)
	elif seq_t < 1.45:
		# выдёргивает водителя на землю
		var k3 := smoothstep(0.0, 1.0, (seq_t - 0.9) / 0.55)
		h.pull = k3
		player.global_position = door_p + to_car * (0.3 - 0.5 * k3)
		if jack_driver != null and is_instance_valid(jack_driver):
			var from := seat_p + Vector3(0, -0.45, 0)
			var to := ground + out_dir * 0.7
			var arc := sin(k3 * PI) * 0.6
			jack_driver.global_position = from.lerp(to, k3) + Vector3(0, arc - 0.45 * (1.0 - k3) + 0.15 * k3 - 0.45 * k3 * 0.0, 0)
			jack_driver.rotation.z = k3 * 1.45
			jack_driver.rotation.y = car.global_rotation.y
		h.animate(delta, 0.0)
		if seq_t - delta < 1.2 and seq_t >= 1.2:
			Sfx.play("hurt", 0.8)
			shake_t = 0.25
	else:
		# поправляет плечи и садится
		h.lean_in = 0.0
		h.pull = 0.0
		if jack_driver != null and is_instance_valid(jack_driver):
			var d := jack_driver
			jack_driver = null
			var tw := d.create_tween()
			tw.tween_interval(3.0)
			tw.tween_property(d, "scale", Vector3.ONE * 0.01, 0.3)
			tw.tween_callback(d.queue_free)
		car_seq = "in"
		seq_t = 0.38
		seq_from = player.global_position

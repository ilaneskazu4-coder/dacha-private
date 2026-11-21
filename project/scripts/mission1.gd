class_name Mission1
extends Node
## Миссия 1 «Волчий налог» — ограбление в духе больших городских игр: команда из троих, у каждого своя роль.
##  Михалыч (0) отвлекает охранника в холле, Тревор (1) выбивает служебную дверь, Джейсон (2) вскрывает сейф.
##  Потом сигнализация, розыск и побег. Смена героя — кнопка «→»: все трое стоят рядом на карте.
## Сюжет оригинальный: в сейфе Волк-Тауэра лежат липовая оценка дачного участка и контракт застройщика Борзова.

const C := Vector3(48, 0, 76)
const P_LIS := Vector3(-32.0, 0.0, -7.2)
const P_STAGE := Vector3(-6.0, 0.0, -14.0)
const P_LOBBY := Vector3(-6.0, 0.0, -20.4)
const P_DOOR := Vector3(2.6, 0.0, -26.0)
const P_SAFE := Vector3(-6.0, 0.0, -35.6)
const REWARD_CASH := 750
const GUARD_TIME := 70.0
const CRACK_TIME := 6.0

var m: Node3D
var city: Node
var stage := 0          # 0 не начата · 1 едем к башне · 2 дело · 3 побег · 4 готово
var distracted := false
var door_done := false
var alarm := false
var crack := 0.0
var guard_t := 0.0
var t := 0.0
var lis: Npc3D
var beams: Array = []   # [{"node","pos","hero"}]
var layer: CanvasLayer
var bar_top: ColorRect
var bar_bot: ColorRect
var title_lbl: Label
var sub_lbl: Label
var card_t := 0.0
var card_kind := ""
var was_far := false


func setup(main: Node3D, c: Node) -> void:
	m = main
	city = c
	var w: Node3D = m.world
	# Лис — заказчик
	lis = Npc3D.new()
	lis.position = C + P_LIS + Vector3(0, 0, -1.0)
	lis.rotation.y = 0.0
	w.add_child(lis)
	lis.setup("Лис", {"shirt": Color("3a2a2a"), "pants": Color("1c1c22"), "hat": "none", "beard": true,
		"beard_col": Color("2a1a10"), "skin": Color("d9ae88")})
	lis.face_to = m.player
	c.points.append({"pos": C + P_LIS, "r": 2.6, "id": "m1_start"})
	c.points.append({"pos": C + P_LOBBY, "r": 2.4, "id": "m1_lobby"})
	c.points.append({"pos": C + P_DOOR, "r": 2.2, "id": "m1_door"})
	c.points.append({"pos": C + P_SAFE, "r": 2.6, "id": "m1_safe"})
	_dress_tower(w)
	_build_overlay()
	for k in 4:
		var n := _make_beam()
		w.add_child(n)
		n.visible = false
		beams.append({"node": n, "pos": Vector3.ZERO, "hero": -1})


func _dress_tower(w: Node3D) -> void:
	var T := C + Vector3(-6.0, 0.0, -28.0)
	# парадная дверь холла и вывеска охраны
	MeshKit.inst([MeshKit.box(Vector3(2.6, 2.6, 0.12), Vector3(0, 1.3, 6.1), Color("9fd8ff")),
		MeshKit.box(Vector3(2.9, 0.2, 0.3), Vector3(0, 2.7, 6.2), Color("0e1c2e"))], w, T)
	MeshKit.label(Loc.t("ХОЛЛ · ОХРАНА"), Vector3(0, 3.1, 6.35), Color("ffe08a"), 36, 0.012, false, w).position = T + Vector3(0, 3.1, 6.35)
	# служебная дверь сбоку
	MeshKit.inst([MeshKit.box(Vector3(0.12, 2.2, 1.7), Vector3(7.06, 1.1, -2.0), Color("5a5a62")),
		MeshKit.box(Vector3(0.2, 0.2, 1.9), Vector3(7.1, 2.3, -2.0), Color("c9a020"))], w, T)
	MeshKit.label(Loc.t("СЛУЖЕБНЫЙ ВХОД"), Vector3(7.3, 2.8, -2.0), Color("ffd23a"), 28, 0.01, false, w).position = T + Vector3(7.3, 2.8, -2.0)
	# окно сейфовой комнаты на задней стене
	MeshKit.inst([MeshKit.box(Vector3(2.2, 1.4, 0.1), Vector3(0, 1.8, -6.08), Color("c9ffd0")),
		MeshKit.box(Vector3(0.9, 0.9, 0.2), Vector3(0, 1.2, -6.2), Color("6a7a8a"))], w, T)


func _build_overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	bar_top = ColorRect.new()
	bar_top.color = Color.BLACK
	bar_top.anchor_right = 1.0
	bar_top.size = Vector2(1280, 0)
	layer.add_child(bar_top)
	bar_bot = ColorRect.new()
	bar_bot.color = Color.BLACK
	bar_bot.anchor_right = 1.0
	bar_bot.anchor_top = 1.0
	bar_bot.anchor_bottom = 1.0
	layer.add_child(bar_bot)
	title_lbl = Label.new()
	title_lbl.anchor_right = 1.0
	title_lbl.anchor_top = 0.5
	title_lbl.anchor_bottom = 0.5
	title_lbl.offset_top = -60
	title_lbl.offset_bottom = 20
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 64)
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title_lbl.add_theme_constant_override("outline_size", 10)
	title_lbl.modulate.a = 0.0
	layer.add_child(title_lbl)
	sub_lbl = Label.new()
	sub_lbl.anchor_right = 1.0
	sub_lbl.anchor_top = 0.5
	sub_lbl.anchor_bottom = 0.5
	sub_lbl.offset_top = 30
	sub_lbl.offset_bottom = 90
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 28)
	sub_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sub_lbl.add_theme_constant_override("outline_size", 6)
	sub_lbl.modulate.a = 0.0
	layer.add_child(sub_lbl)


func _make_beam() -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.7
	cm.bottom_radius = 0.7
	cm.height = 30.0
	mi.mesh = cm
	mi.position.y = 15.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.85, 0.2, 0.28)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.name = "Beam"
	n.add_child(mi)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.25
	ring.mesh = tm
	ring.position.y = 0.15
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1, 0.85, 0.2)
	ring.material_override = rm
	ring.name = "Ring"
	n.add_child(ring)
	var l := Label3D.new()
	l.name = "Dist"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.012
	l.font_size = 40
	l.position.y = 4.8
	l.outline_size = 10
	n.add_child(l)
	return n


# ------------------------------------------------------------ подсказки / действия

func _hero_name(i: int) -> String:
	return ["Михалыч", "Тревор", "Джейсон"][i]


func label(id: String) -> String:
	var pc: int = m.player.char_id
	match id:
		"m1_start":
			if Game.m1_done:
				return "Лис: работы пока нет"
			if stage == 0:
				return "Поговорить с Лисом"
			return ""
		"m1_lobby":
			if stage != 2 or distracted:
				return ""
			return "Отвлечь охранника" if pc == 0 else "Нужен Михалыч (→)"
		"m1_door":
			if stage != 2 or door_done:
				return ""
			if not distracted:
				return "Охранник смотрит сюда!"
			return "Выбить дверь" if pc == 1 else "Нужен Тревор (→)"
		"m1_safe":
			if stage != 2 or crack >= 1.0:
				return ""
			if not door_done:
				return "Сначала дверь"
			return "Взлом сейфа (держи)" if pc == 2 else "Нужен Джейсон (→)"
	return ""


func act(id: String) -> void:
	var pc: int = m.player.char_id
	match id:
		"m1_start":
			if Game.m1_done:
				_dlg("Лис (посредник)", ["Спасибо, Михалыч. Борзов до сих пор ищет, куда делись бумаги. Придёт новая работа — позвоню."])
			elif stage == 0:
				_briefing()
		"m1_lobby":
			if stage != 2 or distracted:
				return
			if pc != 0:
				_toast("В холл идёт Михалыч: нажми «→», пока не станешь им", Color("ffd23a"))
				return
			_distract()
		"m1_door":
			if stage != 2 or door_done:
				return
			if not distracted:
				_toast("Охранник ещё смотрит на дверь. Сначала Михалыч!", Color("ffd23a"))
				return
			if pc != 1:
				_toast("Дверь выбьет Тревор: нажми «→»", Color("ffd23a"))
				return
			_smash()
		"m1_safe":
			if stage == 2 and door_done and crack < 1.0 and pc != 2:
				_toast("Сейф — работа Джейсона: нажми «→»", Color("ffd23a"))


func _toast(s: String, c: Color) -> void:
	m.ui.toast(s, c)


func _dlg(who: String, lines: Array, cb: Callable = Callable()) -> void:
	m.mode = "dialog"
	m.ui.open_dialog(who, lines, func() -> void:
		m.mode = "play"
		if cb.is_valid():
			cb.call())


func _briefing() -> void:
	_dlg("Лис (посредник)", [
		"Садись, Михалыч. Разговор короткий. Борзов подделал оценку твоего участка. Бумаги и контракт лежат в сейфе на втором этаже Волк-Тауэра.",
		"Берёшь двоих. Ты — лицо: заговоришь охраннику зубы в холле. Тревор — вскрытие: служебная дверь сбоку. Джейсон — сейф, сзади.",
		"Кнопка «→» переключает героев, все трое будут рядом. Охранник отвлечётся минуты на полторы. Не успеете — сработает сигнализация.",
		"И да: убежать придётся. Милиция тут рядом. Удачи, дачники."], func() -> void:
			_start())


func _start() -> void:
	stage = 1
	distracted = false
	door_done = false
	alarm = false
	crack = 0.0
	m.buddy_ai.mode = 1
	m.buddy2_ai.mode = 1
	_card("title", "ВОЛЧИЙ НАЛОГ", "Миссия 1", Color("ffd23a"))
	Sfx.play("coin")


func _plan() -> void:
	stage = 2
	Sfx.play("blip", 1.2)
	_dlg("Команда", [
		"Михалыч: Ну что, я человек мирный. Пойду поговорю.",
		"Тревор: А я человек немирный. Я поговорю с дверью.",
		"Джейсон: Сейф мой. Дайте шесть секунд тишины.",
		"Порядок: Михалыч → Тревор → Джейсон. Герои меняются кнопкой «→»."])


func _distract() -> void:
	_dlg("Охранник", [
		"Михалыч: Мужик, тут у вас дача моя продаётся? Я уточнить хотел... вот тут бумага.",
		"Охранник: Какая дача? Вы кто вообще? Покажите пропуск.",
		"Михалыч: Пропуск? Был же где-то. Сейчас, всё достану, подождите. Целый чемодан бумаг, ей-богу...",
		"Охранник сидит и ждёт, пока Михалыч роется в авоське. Тревору пора."], func() -> void:
			distracted = true
			guard_t = GUARD_TIME
			_toast("Охранник отвлечён! Времени: %d сек" % int(GUARD_TIME), Color("9aff9a"))
			Sfx.play("coin", 1.2))


func _smash() -> void:
	door_done = true
	Sfx.play("hit", 0.6)
	m.ui.toast("Тревор: ДВЕРЬ, ПРИВЕТ!", Color("ff9a6a"))
	_toast("Дверь выбита. Теперь Джейсон — сейф (задняя стена)", Color("9aff9a"))


func _loot() -> void:
	crack = 1.0
	Sfx.play("cheer", 1.2)
	_dlg("Джейсон", [
		"Джейсон: Готово. Оценка, контракт, ещё конверт с фотографиями. Борзов в плёнке — как в кино.",
		"Тревор: Только что-то мигает красным...",
		"Сигнализация! Уходим!"], func() -> void:
			_raise_alarm(3.0))


func _raise_alarm(heat: float) -> void:
	alarm = true
	stage = 3
	m.buddy_ai.mode = 0
	m.buddy2_ai.mode = 0
	city.add_heat(heat, "СИГНАЛИЗАЦИЯ!")
	was_far = false
	m.ui.toast("Оторвись от милиции!", Color("ffd23a"))


func _fail(why: String) -> void:
	stage = 0
	distracted = false
	door_done = false
	alarm = false
	crack = 0.0
	guard_t = 0.0
	_card("fail", "МИССИЯ ПРОВАЛЕНА", why, Color("ff5a5a"))


func _finish() -> void:
	stage = 4
	Game.m1_done = true
	Game.cash += REWARD_CASH
	Game.add_wood(10)
	Game.changed.emit()
	Game.save()
	Sfx.play("cheer", 0.9)
	_card("pass", "ЗАДАНИЕ ВЫПОЛНЕНО", "Волчий налог   +$%d" % REWARD_CASH, Color("ffd23a"))


func _card(kind: String, title: String, sub: String, col: Color) -> void:
	card_kind = kind
	card_t = 0.0
	title_lbl.text = Loc.t(title)
	title_lbl.add_theme_color_override("font_color", col)
	sub_lbl.text = Loc.t(sub)
	sub_lbl.add_theme_color_override("font_color", Color.WHITE)


func objective() -> String:
	match stage:
		1:
			return "Езжай к Волк-Тауэру (жёлтая отметка). Вся команда рядом."
		2:
			if not distracted:
				return "Михалыч: отвлеки охранника в холле (сменить героя — «→»)"
			if not door_done:
				return "Тревор: выбей служебную дверь сбоку. Охранник отвлечён ещё %d сек" % maxi(0, int(guard_t))
			if crack < 1.0:
				return "Джейсон: вскрой сейф на задней стене — держи кнопку (%d%%)" % int(crack * 100.0)
		3:
			return "Оторвись от милиции! Розыск " + "★".repeat(city.stars)
	return ""


func active() -> bool:
	return stage >= 1 and stage <= 3


# ------------------------------------------------------------ цикл

func _near(p: Vector3, r: float) -> bool:
	var pp: Vector3 = m.player.global_position
	if m.mode == "car":
		pp = m.car.global_position
	return Vector2(pp.x - (C.x + p.x), pp.z - (C.z + p.z)).length() < r


func _update_beams() -> void:
	var want: Array = []
	match stage:
		0:
			if not Game.m1_done:
				want.append([P_LIS + Vector3(0, 0, 2.0), Color("ffd23a"), "Лис (посредник)"])
		1:
			want.append([P_STAGE, Color("ffd23a"), "Волк-Тауэр"])
		2:
			if not distracted:
				want.append([P_LOBBY, Color("ffa040"), "Михалыч"])
			elif not door_done:
				want.append([P_DOOR, Color("ff5a4a"), "Тревор"])
			elif crack < 1.0:
				want.append([P_SAFE, Color("5aff7a"), "Джейсон"])
	var pp: Vector3 = m.player.global_position
	for i in beams.size():
		var b: Dictionary = beams[i]
		var n: Node3D = b["node"]
		if i < want.size():
			var wp: Vector3 = C + (want[i][0] as Vector3)
			var col: Color = want[i][1]
			n.visible = true
			n.global_position = wp
			var mat := (n.get_node("Beam") as MeshInstance3D).material_override as StandardMaterial3D
			mat.albedo_color = Color(col.r, col.g, col.b, 0.26)
			((n.get_node("Ring") as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = col
			var d := Vector2(pp.x - wp.x, pp.z - wp.z).length()
			var l := n.get_node("Dist") as Label3D
			l.text = "%s · %d %s" % [Loc.t(want[i][2]), int(d), "m" if Loc.en else "м"]
			l.modulate = col
			n.get_node("Ring").rotation.y = t * 1.5
		else:
			n.visible = false


func _update_card(delta: float) -> void:
	if card_kind == "":
		bar_top.size.y = lerpf(bar_top.size.y, 0.0, clampf(delta * 6.0, 0.0, 1.0))
		bar_bot.offset_top = lerpf(bar_bot.offset_top, 0.0, clampf(delta * 6.0, 0.0, 1.0))
		title_lbl.modulate.a = move_toward(title_lbl.modulate.a, 0.0, delta * 2.0)
		sub_lbl.modulate.a = move_toward(sub_lbl.modulate.a, 0.0, delta * 2.0)
		return
	card_t += delta
	var dur := 3.2 if card_kind == "title" else 5.0
	var letter := card_kind == "title"
	var h_target := 70.0 if letter and card_t < dur - 0.4 else 0.0
	bar_top.size.y = lerpf(bar_top.size.y, h_target, clampf(delta * 7.0, 0.0, 1.0))
	bar_bot.offset_top = lerpf(bar_bot.offset_top, -h_target, clampf(delta * 7.0, 0.0, 1.0))
	var a := clampf(card_t / 0.5, 0.0, 1.0) * clampf((dur - card_t) / 0.6, 0.0, 1.0)
	title_lbl.modulate.a = a
	sub_lbl.modulate.a = a
	var pop := 1.0 + 0.12 * clampf(1.0 - card_t * 3.0, 0.0, 1.0)
	title_lbl.pivot_offset = Vector2(640, 40)
	title_lbl.scale = Vector2(pop, pop)
	if card_t >= dur:
		card_kind = ""


func _process(delta: float) -> void:
	if m == null or m.player == null:
		return
	t += delta
	_update_beams()
	_update_card(delta)
	if stage == 0 or stage >= 4:
		return
	if m.mode == "dead":
		_fail("Ты погиб. Лис ждёт у пивной.")
		return
	match stage:
		1:
			if _near(P_STAGE, 6.0) and m.mode != "dialog" and not m.ui.dlg_active:
				_plan()
		2:
			if distracted and not alarm and crack < 1.0:
				guard_t -= delta
				if guard_t <= 0.0:
					alarm = true
					city.add_heat(2.0, "СИГНАЛИЗАЦИЯ!")
					_toast("Охранник очнулся! Скорее, пока милиция едет!", Color("ff6a6a"))
			# вскрытие сейфа — держать кнопку
			if door_done and crack < 1.0 and m.player.char_id == 2 and _near(P_SAFE, 2.8) \
					and m.mode == "play" and not m.ui.dlg_active:
				if m.ui.is_a_held():
					crack += delta / CRACK_TIME
					if int(t * 6.0) % 3 == 0:
						Sfx.play("blip", 1.6 + crack)
					if crack >= 1.0:
						_loot()
				else:
					crack = maxf(0.0, crack - delta * 0.4)
			elif crack > 0.0 and crack < 1.0:
				crack = maxf(0.0, crack - delta * 0.4)
		3:
			var sp: Vector3 = m.SPAWN
			if m.player.global_position.distance_to(sp) < 4.0 and city.stars == 0:
				_fail("Тебя арестовали, бумаги конфискованы.")
				return
			if city.stars == 0 and not _near(Vector3(0, 0, 14), 10.0):
				_finish()

extends Node
## Приколы для игры вместе: взрывные бочки, батуты, воскрешение друзей, соревнования.

const BARREL_N := 12
const BOOM_R := 7.5
const PADS := [Vector3(9, 0, -9), Vector3(-10, 0, -6), Vector3(4, 0, 12), Vector3(-7, 0, 14)]

var m: Node3D
var barrels: Array = []      # {"node","pos","alive"}
var pad_cd := 0.0
var rev_t := 0.0
var rev_id := 0
var dead_t := 0.0
var last_attacker := 0
var last_attacker_t := 0.0
var car_cd := {}
var act := ""
var act_left := 0.0
var scores := {}
var sync_t := 0.0
var hit_cd := 0.0


func _ready() -> void:
	m = get_parent()
	for i in BARREL_N:
		var a := 0.3 + i * 0.628
		var r := 12.0 + (i % 3) * 6.0 + float(i % 2) * 3.0
		var pos := Vector3(cos(a) * r, 0.0, -2.0 + sin(a) * r)
		var n := Node3D.new()
		n.position = pos
		m.add_child(n)
		var parts: Array = [
			MeshKit.cyl(0.42, 0.42, 1.0, Vector3(0, 0.5, 0), Color("c0301f"), Vector3.ZERO, 12),
			MeshKit.cyl(0.44, 0.44, 0.12, Vector3(0, 0.25, 0), Color("2a2a2a"), Vector3.ZERO, 12),
			MeshKit.cyl(0.44, 0.44, 0.12, Vector3(0, 0.78, 0), Color("2a2a2a"), Vector3.ZERO, 12),
			MeshKit.box(Vector3(0.3, 0.02, 0.3), Vector3(0, 1.01, 0), Color("ffd23a"))]
		MeshKit.inst(parts, n)
		barrels.append({"node": n, "pos": pos, "alive": true})
	for p in PADS:
		var n := Node3D.new()
		n.position = p
		m.add_child(n)
		var parts: Array = [
			MeshKit.cyl(1.0, 1.1, 0.18, Vector3(0, 0.09, 0), Color("2a2f3a"), Vector3.ZERO, 16),
			MeshKit.cyl(0.8, 0.8, 0.22, Vector3(0, 0.1, 0), Color("39e07a"), Vector3.ZERO, 16)]
		MeshKit.inst(parts, n)
		var l := OmniLight3D.new()
		l.light_color = Color("39e07a")
		l.omni_range = 5.0
		l.light_energy = 0.8
		l.position = Vector3(0, 0.6, 0)
		n.add_child(l)


func _process(delta: float) -> void:
	if not Net.active or m == null:
		return
	pad_cd = maxf(0.0, pad_cd - delta)
	hit_cd = maxf(0.0, hit_cd - delta)
	last_attacker_t = maxf(0.0, last_attacker_t - delta)
	for k in car_cd.keys():
		car_cd[k] = float(car_cd[k]) - delta
	_pads()
	_revive_logic(delta)
	_dead_logic(delta)
	_act_logic(delta)


func _pads() -> void:
	if m.mode != "play" or pad_cd > 0.0 or m.in_club or m.in_house != "":
		return
	var pp: Vector3 = m.player.global_position
	for p in PADS:
		if Vector2(pp.x - p.x, pp.z - p.z).length() < 1.1 and pp.y < 0.6:
			var dir := Vector3(-sin(m.player.face), 0.0, -cos(m.player.face))
			m.player.velocity = dir * 7.0 + Vector3(0, 15.0, 0)
			pad_cd = 1.0
			Sfx.play("fell", 1.8)
			m.ui.toast("БАТУТ!", Color("39e07a"))
			return


# --- воскрешение друзей ---
func _revive_logic(delta: float) -> void:
	if m.mode != "play" or Game.hp <= 0.0:
		rev_t = 0.0
		return
	var best := 0
	for id in Net.remotes:
		var rp := Net.remotes[id] as RemotePlayer
		if rp != null and rp.dead and not rp.first and rp.global_position.distance_to(m.player.global_position) < 3.4:
			best = int(id)
			break
	if best == 0:
		rev_t = 0.0
		rev_id = 0
		return
	if best != rev_id:
		rev_id = best
		rev_t = 0.0
	rev_t += delta
	if rev_t >= 2.0:
		rev_t = 0.0
		Net.send_revive(best)
		m.ui.toast("Ты поднял друга!", Color("9aff9a"))


func _dead_logic(delta: float) -> void:
	if m.mode != "dead":
		dead_t = 0.0
		return
	dead_t += delta
	if dead_t < 12.0:
		m.ui.modal_sub = "Друг рядом может поднять тебя! Или возродись сам (осталось: %d)" % ceili(12.0 - dead_t)
		m.ui.modal_btn0 = "Ждём помощь друга…"
	else:
		m.ui.modal_sub = "Друг ещё может поднять тебя"
		m.ui.modal_btn0 = "Возродиться здесь (половина здоровья)"


# --- бочки ---
func _barrel_at(pos: Vector3, r: float) -> int:
	var best := -1
	var bd := r
	for i in barrels.size():
		var b: Dictionary = barrels[i]
		if not b["alive"]:
			continue
		var d: float = (b["pos"] as Vector3).distance_to(Vector3(pos.x, 0.0, pos.z))
		if d < bd:
			bd = d
			best = i
	return best


func boom(i: int, chain: bool = false) -> void:
	if i < 0 or i >= barrels.size() or not barrels[i]["alive"]:
		return
	var b: Dictionary = barrels[i]
	b["alive"] = false
	var pos: Vector3 = b["pos"]
	(b["node"] as Node3D).visible = false
	_effect(pos)
	var pp: Vector3 = m.player.global_position
	var d := pp.distance_to(pos + Vector3(0, 0.5, 0))
	if d < BOOM_R and m.mode in ["play", "fish"]:
		var k := 1.0 - d / BOOM_R
		m.player.invuln = 0.0
		m.player.hurt(28.0 * k, pos - (pp - pos).normalized() * 0.1, 9.0 + 9.0 * k, 8.0 + 6.0 * k, 1.6)
	if Net.is_host:
		for w in get_tree().get_nodes_in_group("wolves"):
			var wf := w as Wolf3D
			if wf != null and not wf.dead and wf.global_position.distance_to(pos) < BOOM_R + 1.0:
				wf.hurt(70.0, pos, 14.0)
	for j in barrels.size():
		if j != i and barrels[j]["alive"] and (barrels[j]["pos"] as Vector3).distance_to(pos) < 6.0:
			get_tree().create_timer(0.25).timeout.connect(boom.bind(j, true))
	get_tree().create_timer(45.0).timeout.connect(func() -> void:
		if is_instance_valid(b["node"]):
			b["alive"] = true
			(b["node"] as Node3D).visible = true)


func _effect(pos: Vector3) -> void:
	Sfx.play("fell", 0.45)
	Sfx.play("howl", 1.6)
	var p := CPUParticles3D.new()
	p.position = pos + Vector3(0, 0.8, 0)
	p.emitting = true
	p.one_shot = true
	p.amount = 40
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 70.0
	p.initial_velocity_min = 5.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0, -9.0, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
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
	l.light_energy = 6.0
	l.omni_range = 14.0
	l.position = pos + Vector3(0, 1.0, 0)
	m.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.6)
	tw.tween_callback(l.queue_free)
	get_tree().create_timer(1.5).timeout.connect(p.queue_free)


# --- удары топором и машиной ---
## Вернёт true, если удар ушёл в бочку или в друга.
func on_chop(ppos: Vector3, fwd: Vector3) -> bool:
	var bi := _barrel_at(ppos + fwd * 1.3, 1.6)
	if bi >= 0:
		boom(bi)
		Net.send_boom(bi)
		return true
	if not (Net.pvp or act == "axe"):
		return false
	var best := 0
	var bd := 2.6
	for id in Net.remotes:
		var rp := Net.remotes[id] as RemotePlayer
		if rp == null or rp.dead or rp.first:
			continue
		var d := rp.global_position - ppos
		d.y = 0.0
		if d.length() < bd and d.normalized().dot(fwd) > 0.0:
			bd = d.length()
			best = int(id)
	if best == 0:
		return false
	if act == "axe":
		Net.send_pvp_hit(best, 0.0, ppos, 9.0, 4.0, 0.9)
		Net.send_score(1)
	else:
		Net.send_pvp_hit(best, 18.0, ppos, 8.0, 2.5, 0.5)
	Sfx.play("hit", 0.9)
	return true


func car_hit(car: Node3D) -> void:
	var spd := absf(float(car.speed))
	if spd < 6.0:
		return
	var bi := _barrel_at(car.global_position, 3.2)
	if bi >= 0:
		boom(bi)
		Net.send_boom(bi)
	for id in Net.remotes:
		var rp := Net.remotes[id] as RemotePlayer
		if rp == null or rp.dead or rp.first or (rp.flags & 2) != 0:
			continue
		if rp.global_position.distance_to(car.global_position) < 2.7 and float(car_cd.get(id, 0.0)) <= 0.0:
			car_cd[id] = 1.5
			var dmg := clampf(spd * 2.2, 8.0, 40.0) if Net.pvp else 0.0
			Net.send_pvp_hit(int(id), dmg, car.global_position, minf(spd * 0.9, 16.0), 6.0, 1.6)
			m.ui.toast("Сбил друга!", Color("ffd23a"))
			if act == "axe":
				Net.send_score(1)


func got_hit(attacker: int) -> void:
	last_attacker = attacker
	last_attacker_t = 6.0


func on_died() -> void:
	if last_attacker_t > 0.0 and Net.players.has(last_attacker):
		var msg := "%s вырубил %s" % [Net.players[last_attacker]["name"], Net.my_name]
		Net.send_toast(msg)
		m.net_toast(msg)


# --- соревнования ---
const ACT_INTRO := {
	"wood": "ГОНКА ДРОВ: руби больше всех деревьев!",
	"axe": "БОЙ НА ТОПОРАХ: сбивай друзей, урона нет!",
	"race": "ГОНКА ПО ГОРОДУ: проезжай огни по кругу, кто больше!",
	"cash": "ДЕНЕЖНАЯ ГОНКА: заработай больше всех за 90 секунд!"}
const ACT_TITLE := {"wood": "ГОНКА ДРОВ", "axe": "БОЙ НА ТОПОРАХ", "race": "ГОНКА ПО ГОРОДУ", "cash": "ДЕНЬГИ"}
var cp_i := 0
var cp_node: Node3D = null
var last_cash := 0


func _cp_pos(i: int) -> Vector3:
	var C: Vector3 = m.city.C
	var pts := [Vector3(-36, 0, 3), Vector3(0, 0, 3), Vector3(36, 0, 3), Vector3(36, 0, -3), Vector3(0, 0, -3), Vector3(-36, 0, -3)]
	return C + (pts[i % pts.size()] as Vector3)


func _cp_show() -> void:
	if cp_node != null and is_instance_valid(cp_node):
		cp_node.queue_free()
	cp_node = null
	if act != "race":
		return
	cp_node = Node3D.new()
	m.world.add_child(cp_node)
	cp_node.global_position = _cp_pos(cp_i)
	MeshKit.glow_inst([MeshKit.cyl(2.2, 2.2, 14.0, Vector3(0, 7, 0), Color.WHITE, Vector3.ZERO, 16)], Color("ffcc33"), cp_node, 1.6)


func _cp_logic() -> void:
	if act == "race":
		var pos: Vector3 = m.car.global_position if m.mode == "car" else m.player.global_position
		var t := _cp_pos(cp_i)
		if Vector2(pos.x - t.x, pos.z - t.z).length() < 6.0:
			cp_i += 1
			Net.send_score(1)
			Sfx.play("coin", 1.2)
			_cp_show()
	elif act == "cash":
		var d: int = Game.cash - last_cash
		last_cash = Game.cash
		if d > 0:
			Net.send_score(d)
func act_start(kind: String, dur: float) -> void:
	act = kind
	act_left = dur
	scores = {}
	sync_t = 0.0
	cp_i = 0
	last_cash = Game.cash
	_cp_show()
	var nm: String = ACT_INTRO.get(kind, "")
	m.ui.toast(nm, Color("ffd23a"))
	Sfx.play("howl", 1.3)


func add_score(id: int, d: int) -> void:
	if act == "":
		return
	scores[id] = int(scores.get(id, 0)) + d


func on_wood() -> void:
	if act == "wood":
		Net.send_score(1)


func act_sync(ids: PackedInt32Array, vals: PackedInt32Array, left: float) -> void:
	if Net.is_host:
		return
	scores = {}
	for i in ids.size():
		scores[ids[i]] = vals[i]
	act_left = left


func act_end(msg: String) -> void:
	var was := act
	act = ""
	_cp_show()
	m.ui.net_hud = ""
	m.ui.toast(msg, Color("ffd23a"))
	if msg.contains(Net.my_name + " "):
		if was == "wood":
			Game.add_wood(10)
		elif was == "race" or was == "cash":
			Game.cash += 100
			Game.changed.emit()


func _act_logic(delta: float) -> void:
	if act == "":
		m.ui.net_hud = ""
		return
	act_left -= delta
	if Net.is_host:
		sync_t -= delta
		if sync_t <= 0.0:
			sync_t = 1.0
			var ids := PackedInt32Array()
			var vals := PackedInt32Array()
			for id in scores:
				ids.append(int(id))
				vals.append(int(scores[id]))
			Net.send_act_sync(ids, vals, act_left)
		if act_left <= 0.0:
			var top := -1
			var topn := ""
			for id in Net.players:
				var sc := int(scores.get(id, 0))
				if sc > top:
					top = sc
					topn = String(Net.players[id]["name"])
			Net.send_act_end("Победил %s — %d очк.%s" % [topn, top, " (+10 брёвен)" if act == "wood" else (" (+$100)" if act == "race" or act == "cash" else "")])
			act = ""
			return
	_cp_logic()
	var title: String = ACT_TITLE.get(act, "")
	var txt := "%s  0:%02d" % [title, maxi(0, ceili(act_left))]
	var ids2: Array = Net.players.keys()
	ids2.sort_custom(func(a: Variant, b: Variant) -> bool: return int(scores.get(a, 0)) > int(scores.get(b, 0)))
	for id in ids2:
		txt += "\n%s: %d" % [Net.players[id]["name"], int(scores.get(id, 0))]
	m.ui.net_hud = txt

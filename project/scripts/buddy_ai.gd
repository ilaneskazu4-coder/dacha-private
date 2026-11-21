class_name BuddyAI
extends Node
## Напарник: второй герой, пока играешь за другого. Рубит лес, дерётся с волками и милицией,
## ходит за тобой или стоит. Если ударить его — разозлится и полезет драться с тобой.

const MODES := ["Авто", "За мной", "Стоять", "Драка"]
var m: Node3D
var b: Player3D
var mode := 0
var target: Node3D = null
var tgt_pos := Vector3.ZERO
var think_t := 0.0
var stuck_t := 0.0
var last_pos := Vector3.ZERO
var jump_cd := 0.0
var idle_fx := 3.0
var tree_i := -1
var enabled := true


func setup(main: Node3D, buddy: Player3D) -> void:
	m = main
	b = buddy
	b.chop_hit.connect(_on_hit)
	b.special_hit.connect(_on_special)


func cycle_mode() -> String:
	mode = (mode + 1) % MODES.size()
	return MODES[mode]


func _player() -> Player3D:
	return m.player


func _dist(a: Vector3, c: Vector3) -> float:
	return Vector2(a.x - c.x, a.z - c.z).length()


func _wolf_target(r: float) -> Node3D:
	var best: Node3D = null
	var bd := r
	for w in b.get_tree().get_nodes_in_group("wolves"):
		var wf := w as Wolf3D
		if wf == null or wf.dead:
			continue
		var d := _dist(wf.global_position, b.global_position)
		if d < bd:
			bd = d
			best = wf
	return best


func _human_target(r: float, cops_only: bool) -> Node3D:
	var best: Node3D = null
	var bd := r
	var city = m.city
	for c in city.cops:
		if not is_instance_valid(c) or (c as Cop3D).dying:
			continue
		var d := _dist((c as Node3D).global_position, b.global_position)
		if d < bd:
			bd = d
			best = c
	if not cops_only:
		for pd in city.peds:
			if float(pd["dead"]) > 0.0:
				continue
			var n: Node3D = pd["n"]
			var d2 := _dist(n.global_position, b.global_position)
			if d2 < bd:
				bd = d2
				best = n
	return best


func _tree_target() -> void:
	var f: Forest = m.forest
	var best := -1
	var bd := 38.0
	for i in f.items.size():
		var it: Dictionary = f.items[i]
		if it["alive"] and it["kind"] == "tree":
			var d := _dist(it["pos"], b.global_position)
			# не уходим слишком далеко от игрока
			if d < bd and _dist(it["pos"], _player().global_position) < 55.0:
				bd = d
				best = i
	tree_i = best


func _pick(delta: float) -> void:
	target = null
	tree_i = -1
	var pl := _player()
	if b.anger > 0.0:
		target = pl
		return
	var w := _wolf_target(16.0)
	if w != null and mode != 2:
		target = w
		return
	if w != null and _dist(w.global_position, b.global_position) < 4.0:
		target = w
		return
	if m.city.stars > 0 and mode != 2:
		var c := _human_target(18.0, true)
		if c != null:
			target = c
			return
	if mode == 3:
		var h := _human_target(28.0, false)
		if h != null:
			target = h
			return
	if mode == 0 and b.char_id == 0 and _dist(b.global_position, pl.global_position) < 40.0:
		_tree_target()


func _go(p: Vector3, delta: float, stop: float, run: bool = true) -> bool:
	var d := p - b.global_position
	d.y = 0.0
	if d.length() <= stop:
		b.walk(Vector3.ZERO, delta)
		return true
	b.walk(d.normalized() * (1.0 if run else 0.55), delta)
	return false


func _face_to(p: Vector3, delta: float) -> void:
	var d := p - b.global_position
	b.face = lerp_angle(b.face, atan2(-d.x, -d.z), clampf(14.0 * delta, 0.0, 1.0))


func tick(delta: float) -> void:
	if not enabled or not b.visible:
		return
	var pl := _player()
	b.anger = maxf(0.0, b.anger - delta)
	jump_cd = maxf(0.0, jump_cd - delta)
	if b.down_t > 0.0:
		b.walk(Vector3.ZERO, delta)
		return
	var dp := _dist(pl.global_position, b.global_position)
	# слишком далеко (или застрял) — подбегает рядом
	if dp > 60.0 or stuck_t > 3.0:
		_warp_near(pl.global_position)
		stuck_t = 0.0
		return
	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.35
		_pick(delta)
	var moved := _dist(b.global_position, last_pos)
	last_pos = b.global_position
	var want_move := false
	if target != null and is_instance_valid(target):
		var tp := target.global_position
		var d := _dist(tp, b.global_position)
		var reach := 1.8 if (b.fists() or b.char_id >= 1) else 2.1
		if d > reach:
			_go(tp, delta, reach - 0.3)
			want_move = true
		else:
			b.walk(Vector3.ZERO, delta)
			_face_to(tp, delta)
			if not b.swinging():
				b.swing()
				Sfx.play("chop", 1.2)
	elif tree_i >= 0:
		var it: Dictionary = (m.forest as Forest).items[tree_i]
		var tp2: Vector3 = it["pos"]
		if not it["alive"]:
			tree_i = -1
		elif _dist(tp2, b.global_position) > 1.6:
			_go(tp2, delta, 1.4)
			want_move = true
		else:
			b.walk(Vector3.ZERO, delta)
			_face_to(tp2, delta)
			if not b.swinging():
				b.swing()
				Sfx.play("chop", 1.1)
	else:
		var stay := mode == 2
		var want := 3.2 if mode != 2 else 1000.0
		if not stay and dp > want:
			_go(pl.global_position, delta, want - 1.0, dp > 9.0)
			want_move = true
		else:
			b.walk(Vector3.ZERO, delta)
			idle_fx -= delta
			if idle_fx <= 0.0:
				idle_fx = randf_range(4.0, 8.0)
				if b.char_id >= 1 and not b.swinging():
					b.swing()      # разминка: бьёт тень
				elif b.char_id == 0 and not b.swinging():
					b.swing()
	if want_move and moved < 0.01 * (delta * 60.0) + 0.002:
		stuck_t += delta
		if jump_cd <= 0.0 and stuck_t > 0.4:
			b.jump()
			jump_cd = 1.2
	elif want_move:
		stuck_t = maxf(0.0, stuck_t - delta)
	else:
		stuck_t = 0.0
	# спец: сам использует, когда рядом враг
	if target != null and b.can_special() and _dist(target.global_position, b.global_position) < 3.5 and target != _player():
		b.special()


func _warp_near(p: Vector3) -> void:
	var a := randf() * TAU
	b.global_position = p + Vector3(cos(a), 0.2, sin(a)) * 3.0
	b.velocity = Vector3.ZERO


func _on_hit() -> void:
	var fwd := Vector3(-sin(b.face), 0.0, -cos(b.face))
	var pos := b.global_position
	var mul := b.swing_mul()
	# игрок под ударом (если напарник злится)
	var pl := _player()
	var to := pl.global_position - pos
	to.y = 0.0
	if b.anger > 0.0 and to.length() < 2.3 and to.normalized().dot(fwd) > 0.0:
		pl.hurt(7.0 * mul, pos, 6.0, 0.0, 0.0)
		m.ui.toast(m._cn(b.char_id) + " " + Loc.t("бьёт в ответ!"), Color("ff8a8a"))
		return
	if b.fists():
		if m.city.hit_ped(pos, fwd, 14.0 * mul, 12.0 * mul):
			b.add_charge(0.08)
			return
		for w in b.get_tree().get_nodes_in_group("wolves"):
			var wf := w as Wolf3D
			if wf != null and not wf.dead:
				var d := wf.global_position - pos
				d.y = 0.0
				if d.length() < 2.4 and d.normalized().dot(fwd) > 0.0:
					wf.hurt(5.0 * mul, pos, 5.0 + (5.0 if b.combo == 2 else 0.0))
					b.add_charge(0.07)
					return
		return
	if m.city.hit_ped(pos, fwd):
		return
	for w in b.get_tree().get_nodes_in_group("wolves"):
		var wf2 := w as Wolf3D
		if wf2 != null and not wf2.dead:
			var d2 := wf2.global_position - pos
			d2.y = 0.0
			if d2.length() < 2.8 and d2.normalized().dot(fwd) > 0.1:
				wf2.hurt(15.0, pos, 8.0)
				b.add_charge(0.07)
				return
	var f: Forest = m.forest
	var res := f.hit_at(pos + fwd * 1.3, 1.9, pos)
	if res.is_empty():
		return
	if Net.active:
		Net.send_hit(int(res["i"]), pos)
	if res["felled"]:
		if res["kind"] == "tree":
			Game.add_wood(3)
			m.ui.toast(m._cn(b.char_id) + ": " + Loc.t("+3 бревна"), Color("e8b878"))
			Sfx.play("fell")
		else:
			Game.add_stone(2)
			Sfx.play("fell", 1.4)
		b.add_charge(0.1)
	else:
		Sfx.play("chop", 0.9)


func _on_special(kind: int) -> void:
	m.special_effect(b, kind, false)

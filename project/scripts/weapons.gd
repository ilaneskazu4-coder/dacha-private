extends Node
## Оружие игрока: пистолет и дробовик, автонаводка, трассеры, патроны.

const NAMES := ["Топор", "Пистолет", "Дробовик", "Руки"]
const SHORT := ["Топор", "Пист.", "Дроб.", "Руки"]

var m: Node3D
var cur := 0
var cd := 0.0
var last_shot_t := 0.0


func _ready() -> void:
	m = get_parent()


func owned() -> Array:
	var a := [0]
	if Game.has_pistol:
		a.append(1)
	if Game.has_shotgun:
		a.append(2)
	a.append(3)   # «Руки»: убрать всё из рук
	return a


func cycle() -> void:
	var o := owned()
	cur = o[(o.find(cur) + 1) % o.size()]
	m.player.set_weapon(cur)
	Sfx.play("blip", 1.2)
	m.ui.toast("Оружие: %s" % label(true), Color("ffd23a"))


func ammo() -> int:
	return Game.ammo_p if cur == 1 else (Game.ammo_s if cur == 2 else 0)


func label(long: bool = false) -> String:
	if cur == 0:
		return "Топор" if m.player.char_id == 0 else "Кулаки"
	if cur == 3:
		return "Руки"
	return "%s %d" % [NAMES[cur] if long else SHORT[cur], ammo()]


func reset() -> void:
	cur = 0
	if m != null and m.player != null:
		m.player.set_weapon(0)


func _process(delta: float) -> void:
	cd = maxf(0.0, cd - delta)
	last_shot_t += delta
	m.ui.w_label = label()


func _targets() -> Array:
	var t: Array = []
	for pd in m.city.peds:
		if float(pd["dead"]) <= 0.0:
			t.append({"pos": (pd["n"] as Node3D).global_position + Vector3(0, 1.1, 0), "r": 0.55, "kind": "ped", "ref": pd})
	for c in m.city.cops:
		if is_instance_valid(c) and not (c as Cop3D).dying:
			t.append({"pos": (c as Node3D).global_position + Vector3(0, 1.1, 0), "r": 0.55, "kind": "cop", "ref": c})
	if m.city.heli != null and is_instance_valid(m.city.heli) and not m.city.heli.dying:
		t.append({"pos": m.city.heli.global_position, "r": 1.7, "kind": "heli", "ref": m.city.heli})
	for w in get_tree().get_nodes_in_group("wolves"):
		var wf := w as Wolf3D
		if wf != null and not wf.dead:
			t.append({"pos": wf.global_position + Vector3(0, 0.6, 0), "r": 0.75, "kind": "wolf", "ref": wf})
	if Net.active and Net.pvp:
		for id in Net.remotes:
			var rp := Net.remotes[id] as RemotePlayer
			if rp != null and not rp.dead and not rp.first:
				t.append({"pos": rp.global_position + Vector3(0, 1.1, 0), "r": 0.55, "kind": "remote", "ref": int(id)})
	return t


func try_fire() -> bool:
	if cur == 0 or cur == 3:
		return false
	if cd > 0.0:
		return true
	if ammo() <= 0:
		cd = 0.5
		m.ui.toast("Нет патронов!", Color("ff8a8a"))
		return true
	if cur == 1:
		Game.ammo_p -= 1
		cd = 0.32
	else:
		Game.ammo_s -= 1
		cd = 0.85
	Game.changed.emit()
	var p: Player3D = m.player
	var fwd := Vector3(-sin(p.face), 0.0, -cos(p.face))
	var o := p.global_position + Vector3(0, 1.35, 0) + fwd * 0.55
	var tg := _targets()
	var dir := fwd
	var best_ang := 0.42
	for t in tg:
		var d: Vector3 = (t["pos"] as Vector3) - o
		if d.length() > 46.0:
			continue
		var flat := Vector3(d.x, 0.0, d.z).normalized()
		var ang := acos(clampf(flat.dot(fwd), -1.0, 1.0))
		if ang < best_ang:
			best_ang = ang
			dir = d.normalized()
	var pellets := 1 if cur == 1 else 6
	var dmg := 40.0 if cur == 1 else 24.0
	var rng_max := 40.0 if cur == 1 else 16.0
	var hit_any := false
	for k in pellets:
		var d := dir
		if cur == 2:
			d = d.rotated(Vector3.UP, randf_range(-0.13, 0.13)).rotated(d.cross(Vector3.UP).normalized(), randf_range(-0.04, 0.04))
		var res := _cast(o, d, rng_max, tg)
		var end: Vector3 = res["end"]
		tracer(o, end, Color("ffe08a"))
		if res.has("t"):
			_apply(res["t"], dmg, o)
			hit_any = true
	Sfx.play("shot" if cur == 1 else "shotgun", randf_range(0.95, 1.05))
	p.recoil_t = 0.12
	_flash(o)
	m.city.on_shot()
	return true


func _cast(o: Vector3, d: Vector3, rmax: float, tg: Array) -> Dictionary:
	var space := m.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(o, o + d * rmax)
	q.exclude = [m.player.get_rid()]
	for cc in m.cars:
		q.exclude.append((cc as Car3D).get_rid())
	var h := space.intersect_ray(q)
	var wall := rmax
	if not h.is_empty():
		wall = o.distance_to(h["position"])
	var best_t := wall
	var best: Variant = null
	for t in tg:
		var tp: Vector3 = t["pos"]
		var tt := (tp - o).dot(d)
		if tt < 0.4 or tt > best_t:
			continue
		if (tp - (o + d * tt)).length() < float(t["r"]) + 0.25:
			best_t = tt
			best = t
	var out := {"end": o + d * best_t}
	if best != null:
		out["t"] = best
	return out


func _apply(t: Dictionary, dmg: float, o: Vector3) -> void:
	match String(t["kind"]):
		"ped":
			m.city._damage(t["ref"], dmg * 1.4, o)
		"cop":
			m.city.cop_hurt(t["ref"], dmg * 1.4, o)
		"heli":
			m.city.heli_hurt(t["ref"], dmg)
		"wolf":
			(t["ref"] as Wolf3D).hurt(dmg, o, 5.0)
		"remote":
			Net.send_pvp_hit(int(t["ref"]), dmg * 0.5, o, 5.0, 1.5, 0.5)


func tracer(a: Vector3, b: Vector3, col: Color) -> void:
	var len := a.distance_to(b)
	if len < 0.3:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.04, 0.04, len)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	mi.mesh = bm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.add_child(mi)
	mi.global_position = (a + b) * 0.5
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
	get_tree().create_timer(0.07).timeout.connect(mi.queue_free)


func _flash(pos: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color("ffcf6a")
	l.light_energy = 5.0
	l.omni_range = 7.0
	m.add_child(l)
	l.global_position = pos
	get_tree().create_timer(0.06).timeout.connect(l.queue_free)

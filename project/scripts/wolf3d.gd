class_name Wolf3D
extends CharacterBody3D
## Волк: гонится за игроком, кусает, ломает постройки, боится костра, умирает от топора, шипов и Пассата.

signal died(w: Wolf3D)
signal bit_player(dmg: float)

const SPEED := 6.2
const BITE_DMG := 9.0
const FIRE_FEAR := 8.5

var hp := 30.0
var kind := "wolf"   # wolf, pup, boss
var spd := SPEED
var bite_dmg := BITE_DMG
var scale_f := 1.0
var kill_value := 1
var target: Node3D
var flee := false
var flee_dir := Vector3.ZERO
var stun_t := 0.0
var bite_cd := 0.0
var struct_cd := 0.0
var spike_cd := 0.0
var t := 0.0
var stuck_t := 0.0
var dead := false
var life := 0.0
var knock := Vector3.ZERO
var legs: Array = []
var body: Node3D
var struct_target: Structure3D
var puppet := false      # волк на экране друга: только показывает, что решил хозяин
var net_id := 0
var net_pos := Vector3.ZERO
var net_yaw := 0.0


func _ready() -> void:
	match kind:
		"pup":
			hp = 15.0
			spd = SPEED * 1.35
			bite_dmg = 5.0
			scale_f = 0.72
		"boss":
			hp = 160.0
			spd = SPEED * 0.9
			bite_dmg = 20.0
			scale_f = 1.7
			kill_value = 5
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.7, 0.95, 1.5) * scale_f
	cs.shape = sh
	cs.position.y = 0.48 * scale_f
	add_child(cs)
	body = Node3D.new()
	add_child(body)
	var grey := Color("6d6d74")
	var dark := Color("4a4a52")
	if kind == "boss":
		grey = Color("3d2f2f")
		dark = Color("261c1c")
	elif kind == "pup":
		grey = Color("9a8f86")
		dark = Color("6d625a")
	var parts: Array = [
		MeshKit.sph(0.42, Vector3(0, 0.78, 0.1), grey, Vector3(0.78, 0.8, 1.55), 10),
		MeshKit.sph(0.3, Vector3(0, 0.82, -0.5), grey.lightened(0.08), Vector3(0.9, 0.95, 0.9), 8),
		MeshKit.sph(0.23, Vector3(0, 0.95, -0.86), grey, Vector3(0.9, 0.85, 1.0), 8),
		MeshKit.box(Vector3(0.15, 0.13, 0.3), Vector3(0, 0.87, -1.1), dark),
		MeshKit.sph(0.04, Vector3(0, 0.92, -1.27), Color.BLACK, Vector3.ONE, 5),
		MeshKit.cyl(0.0, 0.08, 0.24, Vector3(-0.14, 1.2, -0.84), dark, Vector3(0, 0, 0.2), 4),
		MeshKit.cyl(0.0, 0.08, 0.24, Vector3(0.14, 1.2, -0.84), dark, Vector3(0, 0, -0.2), 4),
		MeshKit.cyl(0.02, 0.1, 0.7, Vector3(0, 0.8, 0.82), grey.darkened(0.1), Vector3(-1.1, 0, 0), 6),
		MeshKit.sph(0.3, Vector3(0, 0.55, -0.1), Color("bdbdc4"), Vector3(0.7, 0.4, 1.3), 8)]
	MeshKit.inst(parts, body)
	MeshKit.glow_inst([MeshKit.sph(0.035, Vector3(-0.1, 1.0, -1.0), Color.WHITE, Vector3.ONE, 5),
		MeshKit.sph(0.035, Vector3(0.1, 1.0, -1.0), Color.WHITE, Vector3.ONE, 5)], Color("ff2a1a"), body, 4.0)
	for lp in [Vector3(-0.2, 0.55, -0.45), Vector3(0.2, 0.55, -0.45), Vector3(-0.2, 0.55, 0.55), Vector3(0.2, 0.55, 0.55)]:
		var piv := Node3D.new()
		piv.position = lp
		body.add_child(piv)
		MeshKit.inst([MeshKit.box(Vector3(0.13, 0.55, 0.15), Vector3(0, -0.27, 0), grey.darkened(0.12)),
			MeshKit.box(Vector3(0.14, 0.08, 0.2), Vector3(0, -0.53, -0.03), dark)], piv)
		legs.append(piv)
	body.scale = Vector3.ONE * scale_f
	add_to_group("wolves")


func hurt(dmg: float, from: Vector3, push: float = 6.0) -> void:
	if dead:
		return
	if puppet:
		if stun_t > 0.0:
			return
		Sfx.play("hit", randf_range(0.9, 1.2))
		stun_t = 0.25
		Net.send_wolf_hit(net_id, dmg, from)
		return
	hp -= dmg
	var d := global_position - from
	d.y = 0.0
	knock = d.normalized() * push
	stun_t = 0.25
	Sfx.play("hit", randf_range(0.9, 1.2))
	if hp <= 0.0:
		die()


func die(count_kill: bool = true) -> void:
	if dead:
		return
	dead = true
	collision_layer = 0
	collision_mask = 0
	if count_kill:
		died.emit(self)
	var tw := create_tween()
	tw.tween_property(body, "rotation:z", 1.5, 0.25)
	tw.parallel().tween_property(body, "position:y", -0.25, 0.25)
	tw.tween_interval(0.5)
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.35)
	tw.tween_callback(queue_free)


func run_away() -> void:
	flee = true
	if target != null:
		flee_dir = (global_position - target.global_position)
		flee_dir.y = 0.0
		flee_dir = flee_dir.normalized() if flee_dir.length() > 0.1 else Vector3.RIGHT


func _physics_process(delta: float) -> void:
	if dead:
		return
	if puppet:
		t += delta
		stun_t = maxf(0.0, stun_t - delta)
		var before_p := global_position
		global_position = global_position.lerp(net_pos, clampf(12.0 * delta, 0.0, 1.0))
		rotation.y = lerp_angle(rotation.y, net_yaw, clampf(12.0 * delta, 0.0, 1.0))
		var mv := before_p.distance_to(global_position) / maxf(delta, 0.001)
		var swp := sin(t * 16.0) * 0.8 if mv > 1.0 else 0.0
		legs[0].rotation.x = swp
		legs[3].rotation.x = swp
		legs[1].rotation.x = -swp
		legs[2].rotation.x = -swp
		body.position.y = absf(sin(t * 16.0)) * 0.06 if mv > 1.0 else 0.0
		return
	t += delta
	life += delta
	bite_cd = maxf(0.0, bite_cd - delta)
	struct_cd = maxf(0.0, struct_cd - delta)
	spike_cd = maxf(0.0, spike_cd - delta)
	stun_t = maxf(0.0, stun_t - delta)
	knock = knock.move_toward(Vector3.ZERO, 22.0 * delta)

	var dir := Vector3.ZERO
	var speed := spd
	if flee:
		dir = flee_dir
		speed = spd * 1.1
		if life > 600.0:
			queue_free()
	elif stun_t <= 0.0 and target != null:
		var to := target.global_position - global_position
		to.y = 0.0
		var dist := to.length()
		dir = to.normalized() if dist > 0.01 else Vector3.ZERO
		# костёр пугает: огибаем по касательной
		for f in get_tree().get_nodes_in_group("fires"):
			var fd: Vector3 = global_position - (f as Node3D).global_position
			fd.y = 0.0
			var fl := fd.length()
			if fl < FIRE_FEAR:
				var away := fd.normalized()
				var tang := Vector3(-away.z, 0.0, away.x)
				if tang.dot(dir) < 0.0:
					tang = -tang
				dir = (away * 0.9 + tang * 0.5).normalized()
				speed = spd * 0.8
				if fl < 3.5:
					dir = away
		if dist < 1.7 and bite_cd <= 0.0 and Game.hp > 0.0 and flee_dir == Vector3.ZERO:
			bite_cd = 1.0
			bit_player.emit(bite_dmg)
			Sfx.play("bite")
			dir = Vector3.ZERO
		elif dist < 1.5:
			dir = Vector3.ZERO
	var v := dir * speed + knock
	velocity.x = v.x
	velocity.z = v.z
	velocity.y = -4.0
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(10.0 * delta, 0.0, 1.0))
	var before := global_position
	move_and_slide()
	# упёрлись в постройку — грызём её
	var hit_struct: Structure3D = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i).get_collider()
		if c is Structure3D:
			hit_struct = c
			break
	if hit_struct != null and not flee:
		if struct_cd <= 0.0:
			struct_cd = 0.9
			hit_struct.take_damage(12.0)
			Sfx.play("bite", 0.8)
	var moved := before.distance_to(global_position)
	if dir.length() > 0.1 and moved < speed * delta * 0.25:
		stuck_t += delta
		if stuck_t > 1.2 and hit_struct == null:
			stuck_t = 0.0
			knock = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 7.0
	else:
		stuck_t = 0.0
	# шипы
	if spike_cd <= 0.0:
		for sp in get_tree().get_nodes_in_group("spikes"):
			var dd := Vector2(global_position.x - (sp as Node3D).global_position.x, global_position.z - (sp as Node3D).global_position.z).length()
			if dd < 1.25:
				spike_cd = 0.5
				hurt(14.0, (sp as Node3D).global_position, 3.0)
				break
	# анимация
	var sw := sin(t * 16.0) * 0.8 if dir.length() > 0.1 or knock.length() > 1.0 else 0.0
	legs[0].rotation.x = sw
	legs[3].rotation.x = sw
	legs[1].rotation.x = -sw
	legs[2].rotation.x = -sw
	body.position.y = absf(sin(t * 16.0)) * 0.06 if dir.length() > 0.1 else 0.0

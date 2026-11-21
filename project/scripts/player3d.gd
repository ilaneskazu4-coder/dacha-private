class_name Player3D
extends CharacterBody3D
## Михалыч: ходит, рубит топором, получает урон от волков.

signal chop_hit
signal special_hit(kind: int)   # 0 вихрь, 1 удар о землю, 2 приземление в ярости

const SPEED := 5.0
const SWING_TIME := 0.5
const JUMP_V := 7.6

var hum: Humanoid
var speed_mul := 1.0
var swing_t := -1.0
var hit_fired := false
var face := 0.0
var cur_speed := 0.0
var invuln := 0.0
var hurt_t := 0.0
var style_idx := 0
var down_t := 0.0
var downs := 0
var weapon := 0
var recoil_t := 0.0
var axe_mesh: MeshInstance3D
var gun_mesh: MeshInstance3D
var char_id := 0
var is_buddy := false
var bhp := 100.0           # здоровье напарника (у игрока — Game.hp)
var charge := 0.3          # заряд спец-приёма 0..1
var swing_len := SWING_TIME
var combo := 0
var combo_t := 0.0
var spec_t := -1.0         # время спец-приёма
var rage_t := 0.0
var _fired := [false, false, false]
var _was_air := false
var anger := 0.0           # напарник злится на игрока


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	cs.name = "Col"
	add_child(cs)
	floor_snap_length = 0.4
	_build_hum(char_id)


func _build_hum(id: int) -> void:
	char_id = id
	if hum != null:
		hum.queue_free()
	hum = HeroRig.new()
	(hum as HeroRig).setup({"char": id, "tint": Color("ffb0a0") if (is_buddy and id == 0) else Color.WHITE})
	add_child(hum)
	hum.rotation.y = face
	var parts: Array = [
		MeshKit.cyl(0.032, 0.032, 0.95, Vector3(0, -0.72, 0), Color("7a4a24"), Vector3.ZERO, 6),
		MeshKit.box(Vector3(0.06, 0.2, 0.32), Vector3(0, -1.12, -0.12), Color("c9ced6")),
		MeshKit.box(Vector3(0.08, 0.14, 0.1), Vector3(0, -1.12, 0.1), Color("8a8f98"))]
	axe_mesh = MeshKit.inst(parts, hum.arm_r)
	gun_mesh = MeshInstance3D.new()
	hum.arm_r.add_child(gun_mesh)
	gun_mesh.visible = false
	set_weapon(weapon)


func set_char(id: int) -> void:
	if id == char_id and hum != null:
		return
	_build_hum(id)


func fists() -> bool:
	return weapon == 3 or (weapon == 0 and char_id >= 1)


func get_hp() -> float:
	return bhp if is_buddy else Game.hp


func add_charge(v: float) -> void:
	if rage_t <= 0.0 and spec_t < 0.0:
		charge = minf(1.0, charge + v)


func set_weapon(k: int) -> void:
	weapon = k
	axe_mesh.visible = k == 0 and char_id == 0
	gun_mesh.visible = k == 1 or k == 2
	hum.aim = k == 1 or k == 2
	hum.punch = fists()
	if k == 1:
		gun_mesh.mesh = MeshKit.build([MeshKit.box(Vector3(0.07, 0.3, 0.1), Vector3(0, -0.78, 0), Color("22262c")),
			MeshKit.box(Vector3(0.07, 0.16, 0.08), Vector3(0, -0.68, 0.07), Color("3a2a1c"))])
	elif k == 2:
		gun_mesh.mesh = MeshKit.build([MeshKit.box(Vector3(0.07, 0.75, 0.09), Vector3(0, -0.95, 0), Color("22262c")),
			MeshKit.box(Vector3(0.09, 0.3, 0.11), Vector3(0, -0.68, 0.01), Color("6a4326"))])


func _arm_pose() -> float:
	if spec_t >= 0.0 and char_id == 0:
		return 1.55
	if swing_t >= 0.0:
		return _swing_pose()
	if weapon == 1 or weapon == 2:
		recoil_t = maxf(0.0, recoil_t - 0.016)
		return 1.5 + recoil_t * 3.0
	return NAN


func jump() -> void:
	if is_on_floor() and down_t <= 0.0 and get_hp() > 0.0 and spec_t < 0.0:
		velocity.y = JUMP_V
		Sfx.play("blip", 1.6)


func _air_info() -> void:
	hum.air = not is_on_floor()
	hum.vy = velocity.y
	hum.flinch = maxf(hum.flinch, hurt_t) if hurt_t > 0.0 else hum.flinch


func swinging() -> bool:
	return swing_t >= 0.0


func swing() -> void:
	if swing_t >= 0.0 or down_t > 0.0:
		return
	swing_t = 0.0
	hit_fired = false
	if fists():
		combo = (combo + 1) % 3 if combo_t > 0.0 else 0
		hum.attack_kind = combo
		swing_len = 0.55 if combo == 2 else 0.36
	else:
		swing_len = SWING_TIME


func swing_mul() -> float:
	# множитель урона кулачного удара: пинок сильнее, ярость удваивает
	var m := 1.0
	if fists() and combo == 2:
		m = 1.7
	return m * (2.0 if rage_t > 0.0 else 1.0)


func can_special() -> bool:
	return charge >= 1.0 and spec_t < 0.0 and down_t <= 0.0 and swing_t < 0.0


func special() -> bool:
	if not can_special():
		return false
	charge = 0.0
	spec_t = 0.0
	_fired = [false, false, false]
	swing_t = -1.0
	Sfx.play("blip", 0.6)
	return true


func set_active(on: bool) -> void:
	visible = on
	$Col.disabled = not on


func hurt(dmg: float, from: Vector3, push: float = 5.0, lift: float = 0.0, down: float = 0.0) -> void:
	if invuln > 0.0 or get_hp() <= 0.0 or (is_buddy and down_t > 0.0):
		return
	if is_buddy:
		bhp = maxf(0.0, bhp - dmg)
		if bhp <= 0.0:
			down_t = 5.0
			bhp = 45.0
			swing_t = -1.0
	else:
		Game.hp = maxf(0.0, Game.hp - dmg)
	add_charge(dmg * 0.006)
	invuln = 0.55
	if dmg > 0.0:
		hurt_t = 0.5
	var d := global_position - from
	d.y = 0.0
	velocity += d.normalized() * push
	if lift > 0.0:
		velocity.y = lift
	if down > 0.0:
		down_t = down
		downs += 1
		swing_t = -1.0
	Sfx.play("hurt")


func walk(dir: Vector3, delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	hurt_t = maxf(0.0, hurt_t - delta)
	if down_t > 0.0:
		down_t -= delta
		velocity.x = lerpf(velocity.x, 0.0, clampf(2.5 * delta, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, 0.0, clampf(2.5 * delta, 0.0, 1.0))
		velocity.y = velocity.y - 22.0 * delta if not is_on_floor() else -1.0
		move_and_slide()
		cur_speed = 0.0
		hum.rotation.y = face
		hum.rotation.z = lerpf(hum.rotation.z, 1.45, clampf(10.0 * delta, 0.0, 1.0))
		hum.swing_angle = NAN
		return
	hum.rotation.z = lerpf(hum.rotation.z, 0.0, clampf(8.0 * delta, 0.0, 1.0))
	combo_t = maxf(0.0, combo_t - delta)
	rage_t = maxf(0.0, rage_t - delta)
	hum.rage = rage_t > 0.0
	hum.glow = move_toward(hum.glow, 1.0 if rage_t > 0.0 else 0.0, delta * 2.0)
	var spd := SPEED * speed_mul * (0.6 if swing_t >= 0.0 else 1.0) * (1.35 if rage_t > 0.0 else 1.0)
	if spec_t >= 0.0:
		spd *= 0.15 if char_id >= 1 else 0.45
		dir = dir * 0.3
	var v := dir.limit_length(1.0) * spd
	velocity.x = lerpf(velocity.x, v.x, clampf(14.0 * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, v.z, clampf(14.0 * delta, 0.0, 1.0))
	velocity.y = velocity.y - 22.0 * delta if (not is_on_floor() or velocity.y > 0.5) else -1.0
	move_and_slide()
	cur_speed = Vector2(velocity.x, velocity.z).length()
	if _was_air and is_on_floor() and rage_t > 0.0 and spec_t < 0.0:
		special_hit.emit(2)
	_was_air = not is_on_floor()
	_update_special(delta)
	if dir.length() > 0.12 and spec_t < 0.0:
		face = lerp_angle(face, atan2(-dir.x, -dir.z), clampf(12.0 * delta, 0.0, 1.0))
	hum.rotation.y = face
	_update_swing(delta)
	hum.swing_angle = _arm_pose()
	_air_info()
	hum.animate(delta, cur_speed)


func _update_special(delta: float) -> void:
	var h := hum as HeroRig
	h.spin = false
	h.slam = -1.0
	if spec_t < 0.0:
		return
	spec_t += delta
	if char_id == 0:
		# «Лесной вихрь»: оборот топором, три удара по кругу
		var len := 0.8
		face += TAU / len * delta
		h.spin = true
		for i in 3:
			if not _fired[i] and spec_t >= len * (0.2 + 0.25 * i):
				_fired[i] = true
				special_hit.emit(0)
		if spec_t >= len:
			spec_t = -1.0
	else:
		# «Ярость»: удар кулаками о землю → ударная волна → боевой режим
		var len2 := 1.0
		h.slam = clampf(spec_t / len2, 0.0, 1.0)
		if not _fired[0] and spec_t >= len2 * 0.5:
			_fired[0] = true
			rage_t = 12.0
			special_hit.emit(1)
		if spec_t >= len2:
			spec_t = -1.0


func idle(delta: float) -> void:
	invuln = maxf(0.0, invuln - delta)
	hurt_t = maxf(0.0, hurt_t - delta)
	cur_speed = 0.0
	velocity.x = 0.0
	velocity.z = 0.0
	combo_t = maxf(0.0, combo_t - delta)
	rage_t = maxf(0.0, rage_t - delta)
	hum.rotation.y = face
	_update_swing(delta)
	hum.swing_angle = _arm_pose()
	_air_info()
	hum.animate(delta, 0.0)


func _update_swing(delta: float) -> void:
	if swing_t < 0.0:
		return
	swing_t += delta
	if not hit_fired and swing_t >= swing_len * 0.5:
		hit_fired = true
		chop_hit.emit()
	if swing_t >= swing_len:
		swing_t = -1.0
		combo_t = 0.7


func _swing_pose() -> float:
	var k := swing_t / swing_len
	if k < 0.4:
		return lerpf(0.2, 2.9, smoothstep(0.0, 1.0, k / 0.4))
	return lerpf(2.9, 1.15, smoothstep(0.0, 1.0, (k - 0.4) / 0.25))

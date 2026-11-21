class_name Cop3D
extends CharacterBody3D
## Милиционер пешком: бежит к игроку, стреляет, умирает от пуль и топора.

var hum: Humanoid
var hp := 80.0
var shoot_t := 1.5
var dying := false
var cur_speed := 0.0
var face := 0.0
var gun: MeshInstance3D


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	hum = Humanoid.new()
	hum.setup({"shirt": Color("3a5a9a"), "pants": Color("1d2a4a"), "hat": "cap", "hat_col": Color("1a2a5a"),
		"skin": Color("e0b890"), "shoes": Color("15151a")})
	add_child(hum)
	gun = MeshKit.inst([MeshKit.box(Vector3(0.07, 0.3, 0.1), Vector3(0, -0.78, 0), Color("22262c"))], hum.arm_r)


## Один шаг ИИ. Вернёт true, если сделал выстрел в игрока.
func think(delta: float, tp: Vector3, active: bool) -> bool:
	if dying:
		hum.rotation.z = lerpf(hum.rotation.z, 1.45, clampf(10.0 * delta, 0.0, 1.0))
		return false
	var d := tp - global_position
	d.y = 0.0
	var dist := d.length()
	var dir := d.normalized() if dist > 0.01 else Vector3.ZERO
	var spd := 0.0
	if active and dist > 9.0:
		velocity.x = dir.x * 4.4
		velocity.z = dir.z * 4.4
		spd = 8.0
	else:
		velocity.x = lerpf(velocity.x, 0.0, clampf(10.0 * delta, 0.0, 1.0))
		velocity.z = lerpf(velocity.z, 0.0, clampf(10.0 * delta, 0.0, 1.0))
	velocity.y = velocity.y - 22.0 * delta if not is_on_floor() else -1.0
	move_and_slide()
	if dist > 0.5:
		face = lerp_angle(face, atan2(-dir.x, -dir.z), clampf(10.0 * delta, 0.0, 1.0))
	hum.rotation.y = face
	cur_speed = lerpf(cur_speed, spd, clampf(10.0 * delta, 0.0, 1.0))
	hum.animate(delta, cur_speed)
	hum.swing_angle = 1.5 if dist < 24.0 else NAN
	shoot_t -= delta
	if active and dist < 22.0 and shoot_t <= 0.0:
		shoot_t = randf_range(0.9, 1.5)
		return true
	return false


func hurt(dmg: float, _from: Vector3) -> bool:
	if dying:
		return false
	hp -= dmg
	Sfx.play("hit", 1.1)
	if hp <= 0.0:
		dying = true
		collision_layer = 0
		collision_mask = 0
		return true
	return false

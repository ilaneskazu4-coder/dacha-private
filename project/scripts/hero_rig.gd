class_name HeroRig
extends Humanoid
## Дровосек из присланной модели (Meshy): скелет и анимации задаются кодом, вес вершин запечён заранее
## (tools: scripts/_bake_hero.gd). Смотрит в -Z, как остальные Humanoid; сама модель смотрит в +Z и стоит в повёрнутом узле.

const MESH_PATH := "res://assets/hero/hero_mesh.res"

const I_HIPS := 0
const I_SPINE := 1
const I_CHEST := 2
const I_NECK := 3
const I_HEAD := 4
const I_ARM_P := 5
const I_ARM_N := 8
const I_THIGH_P := 11
const I_THIGH_N := 14

var model: Node3D
var skel: Skeleton3D
var mi: MeshInstance3D
var char_id := 0
var swagger := false       # тяжёлая «трэвоская» походка и сутулая стойка
var def: Dictionary = {}
var rest_drop := 0.0
var lower := 1.28          # насколько опущены руки из Т-позы (рад)
var lean_in := 0.0         # наклон в окно машины (угон)
var pull := 0.0            # рывок: вытаскивает водителя
var seat := 0.0            # 0..1 — посадка в машину
var rage := false          # боевая стойка (ярость)
var attack_kind := 0       # 0 правый, 1 левый, 2 пинок
var spin := false           # вихрь: руки раскинуты
var glow := 0.0            # красное свечение ярости 0..1
var slam := -1.0           # 0..1 — удар кулаками о землю (<0 — нет)
var wpitch := 0.2
var tgt: Array = []
var cur: Array = []
var air := false        # в воздухе (ставит игрок)
var vy := 0.0
var aim := false        # держит оружие стрелкового типа
var punch := false      # руки свободны: удар кулаком
var flinch := 0.0       # >0 — только получил удар
var was_air := false
var land_t := 0.0
var fidget_t := 4.0
var fidget_k := 0
var fidget_e := 0.0
var mat: StandardMaterial3D
var walk_amp := 0.0
var lean := 0.0
var twist := 0.0


func _zd(v: float) -> float:
	# углы опускания рук заданы для T-позы; у моделей с рукой уже опущенной в покое вычитаем её наклон
	return v - signf(v) * rest_drop


func setup(s: Dictionary) -> void:
	char_id = int(s.get("char", 0))
	swagger = char_id >= 1
	def = CharDefs.get_def(char_id)
	rest_drop = float(def["rest_drop"])
	lower = float(def["lower"])
	var bones: Array = def["bones"]
	model = Node3D.new()
	model.rotation.y = PI
	model.scale = Vector3.ONE * float(def["scale"])
	add_child(model)
	skel = Skeleton3D.new()
	model.add_child(skel)
	for b in bones:
		skel.add_bone(b[0])
	for i in bones.size():
		skel.set_bone_parent(i, int(bones[i][1]))
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, bones[i][2]))
		skel.set_bone_pose_position(i, bones[i][2])
	mi = MeshInstance3D.new()
	mi.mesh = load(def["mesh"])
	mi.skin = skel.create_skin_from_rest_transforms()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	mat = mi.mesh.surface_get_material(0) as StandardMaterial3D
	var tint: Color = s.get("tint", Color.WHITE)
	mat = mat.duplicate()
	mat.albedo_color = tint
	mi.material_override = mat
	# точка хвата правой руки: оружие вешается сюда (как Humanoid.arm_r), положение берём с кисти, наклон — по углу взмаха
	arm_r = Node3D.new()
	model.add_child(arm_r)
	arm_l = Node3D.new()   # пустышки: чтобы внешний код не падал
	leg_l = Node3D.new()
	leg_r = Node3D.new()
	top_y = 2.0
	for i in bones.size():
		tgt.append(Quaternion.IDENTITY)
		cur.append(Quaternion.IDENTITY)


func _update_weapon(pitch_old: float) -> void:
	wpitch = lerpf(wpitch, pitch_old, 0.6)
	var hp: Vector3 = skel.get_bone_global_pose(10).origin + (def["hand_off"] as Vector3)
	var b := Basis(Vector3.RIGHT, -wpitch) * Basis(Vector3.UP, PI)
	arm_r.basis = b
	arm_r.position = hp + b * Vector3(0, 0.72, 0)


func _rot(i: int, q: Basis) -> void:
	tgt[i] = q.get_rotation_quaternion()


func _apply(delta: float, rate: float) -> void:
	var k := clampf(delta * rate, 0.0, 1.0)
	for i in tgt.size():
		cur[i] = (cur[i] as Quaternion).slerp(tgt[i], k)
		skel.set_bone_pose_rotation(i, cur[i])


func animate(delta: float, speed: float) -> void:
	t += delta
	excite = maxf(0.0, excite - delta)
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3.BACK
	var swinging := not is_nan(swing_angle)
	# ---- танец ----
	if dance:
		var sp := 5.0 + excite * 5.0
		phase += delta * sp
		var bounce := absf(sin(phase + rnd))
		position.y = bounce * (0.04 + excite * 0.16)
		_rot(I_HIPS, Basis(Y, sin(phase * 0.5 + rnd) * 0.4) * Basis(Z, sin(phase + rnd) * 0.1))
		_rot(I_SPINE, Basis(Y, -sin(phase * 0.5 + rnd) * 0.3))
		_rot(I_CHEST, Basis(X, -0.1))
		_rot(I_NECK, Basis.IDENTITY)
		_rot(I_ARM_P, Basis(X, -2.4 - sin(phase * 2.0 + rnd) * 0.5) * Basis(Z, _zd(-lower * 0.3)))
		_rot(I_ARM_P + 1, Basis(X, -0.6))
		_rot(I_ARM_N, Basis(X, -2.4 - cos(phase * 2.0 + rnd) * 0.5) * Basis(Z, _zd(lower * 0.3)))
		_rot(I_ARM_N + 1, Basis(X, -0.6))
		_rot(I_THIGH_P, Basis(X, -sin(phase + rnd) * 0.5))
		_rot(I_THIGH_P + 1, Basis(X, maxf(0.0, sin(phase + rnd)) * 0.9))
		_rot(I_THIGH_N, Basis(X, sin(phase + rnd) * 0.5))
		_rot(I_THIGH_N + 1, Basis(X, maxf(0.0, -sin(phase + rnd)) * 0.9))
		_rot(I_HEAD, Basis(Z, sin(phase + rnd) * 0.15))
		_apply(delta, 16.0)
		_update_weapon(2.0)
		return
	var amp := clampf(speed / 3.0, 0.0, 1.0)
	walk_amp = lerpf(walk_amp, amp, clampf(delta * 10.0, 0.0, 1.0))
	var a := walk_amp
	var idle := sin(t * 1.9 + rnd)
	# ---- приземление и удар ----
	if was_air and not air:
		land_t = 0.24
	was_air = air
	land_t = maxf(0.0, land_t - delta)
	var crouch := sin(land_t / 0.24 * PI) if land_t > 0.0 else 0.0
	flinch = maxf(0.0, flinch - delta)
	var fl := clampf(flinch / 0.4, 0.0, 1.0)
	# ---- ход / бег ----
	if speed > 0.3 and not air:
		phase += delta * (lerpf(3.2 + speed, 9.6, clampf((speed - 2.6) / 2.0, 0.0, 1.0)) if swagger else (4.2 + speed * 1.5))
	elif not air:
		phase = lerpf(phase, roundf(phase / PI) * PI, clampf(delta * 8.0, 0.0, 1.0))
	var s := sin(phase)
	var c := cos(phase)
	var run := clampf((speed - 3.5) / 3.0, 0.0, 1.0)
	if swagger:
		run = clampf((speed - 2.6) / 2.0, 0.0, 1.0)     # у Тревора переход шаг → бег раньше
	var stride := (0.75 + run * 0.35) * a
	if swagger:
		stride = (0.5 + run * 0.4) * a
	var bob := absf(s) * (0.05 + run * 0.05) * a * (1.2 if swagger else 1.0)
	position.y = bob - crouch * 0.12 - seat * 0.42
	if swagger and model != null:
		model.position.x = lerpf(model.position.x, c * 0.02 * a, clampf(delta * 12.0, 0.0, 1.0))   # весь корпус качается над опорной ногой
	var lp := -s * stride
	var ln := s * stride
	if swagger:
		lp -= 0.3 * run * a      # на бегу колено сильно выносится вперёд, как в референсе
		ln -= 0.3 * run * a
	var kp := (0.1 + 0.95 * maxf(0.0, c)) * a
	var kn := (0.1 + 0.95 * maxf(0.0, -c)) * a
	if swagger and run > 0.0:
		# на бегу колено остаётся согнутым и при выносе вперёд (высокий «подъём колена»)
		var cp := cos(phase - 0.65 * run)
		kp = (0.1 + 0.95 * pow(maxf(0.0, cp), 0.75)) * a
		kn = (0.1 + 0.95 * pow(maxf(0.0, -cp), 0.75)) * a
	if swagger:
		kp *= 0.85 + run * 0.8       # на бегу пятка почти к ягодице
		kn *= 0.85 + run * 0.8
	# стойка при рубке на месте: ноги расставлены
	if swinging and not aim and a < 0.4:
		var st := 1.0 - a / 0.4
		lp = lerpf(lp, -0.3, st)
		ln = lerpf(ln, 0.22, st)
		kp = lerpf(kp, 0.28, st)
		kn = lerpf(kn, 0.35, st)
	# прыжок: полёт
	if air:
		var u := clampf(vy / 7.0, -1.0, 1.0)
		var up01 := maxf(0.0, u)
		lp = lerpf(-0.45, -0.95, up01)
		kp = lerpf(0.5, 1.2, up01)
		ln = lerpf(0.15, 0.35, up01) - maxf(0.0, -u) * 0.1
		kn = lerpf(0.45, 0.8, up01)
	if crouch > 0.0:
		lp = lerpf(lp, -0.55, crouch)
		ln = lerpf(ln, -0.45, crouch)
		kp = lerpf(kp, 1.1, crouch)
		kn = lerpf(kn, 1.0, crouch)
	_rot(I_THIGH_P, Basis(X, lp) * Basis(Z, -0.03 - (0.1 if air else 0.0)))
	_rot(I_THIGH_N, Basis(X, ln) * Basis(Z, 0.03 + (0.1 if air else 0.0)))
	_rot(I_THIGH_P + 1, Basis(X, kp))
	_rot(I_THIGH_N + 1, Basis(X, kn))
	# корпус
	var breath := idle * 0.02 * (1.0 - a)
	var lean_t := -(0.06 + run * 0.28) * a - crouch * 0.35 + fl * 0.3
	if swagger:
		lean_t = (0.13 + 0.8 * run) * a - 0.05 * (1.0 - a) - crouch * 0.35 + fl * 0.3
	lean = lerpf(lean, lean_t, clampf(delta * 8.0, 0.0, 1.0))
	var tw := s * ((0.14 + 0.06 * run) if swagger else 0.22) * a
	var head_y := -tw * (0.9 if swagger else 0.4)
	var head_x := -lean * 0.3 + idle * 0.02 * (1.0 - a) - fl * 0.25
	if swagger:
		head_x = -lean * (0.8 - 0.35 * run) + idle * 0.02 * (1.0 - a) - fl * 0.25 + 0.05 + 0.1 * (1.0 - a)   # голова смотрит прямо, не клюёт
		head_y += cos(t * 0.6 + rnd) * 0.1 * (1.0 - a)
	var chest_back := 0.0
	# мелкие «живые» движения в покое
	if a < 0.08 and not swinging and not air:
		fidget_t -= delta
		if fidget_t <= 0.0 and fidget_e <= 0.0:
			fidget_k = randi() % 3
			fidget_e = 1.8
			fidget_t = randf_range(4.0, 9.0)
	if fidget_e > 0.0:
		fidget_e -= delta
		var fe := sin(clampf(fidget_e / 1.8, 0.0, 1.0) * PI)
		if fidget_k == 0:
			head_y += (1.25 if swagger else 0.9) * fe
		elif fidget_k == 1:
			head_y -= (1.25 if swagger else 0.9) * fe
		else:
			chest_back = -0.18 * fe
			head_x -= 0.2 * fe
	var hz := c * 0.03 * a
	var cz := 0.0
	if swagger:
		hz = c * 0.035 * a + sin(t * 0.7 + rnd) * 0.045 * (1.0 - a)   # вразвалку, в покое переносит вес
		cz = -c * 0.05 * a + sin(t * 0.7 + rnd) * 0.03 * (1.0 - a)     # плечо падает на шаге
	_rot(I_HIPS, Basis(Y, -tw * 0.5) * Basis(Z, hz))
	_rot(I_SPINE, Basis(X, lean * 0.5 + breath) * Basis(Y, tw * 0.6) * Basis(Z, cz * 0.5))
	_rot(I_CHEST, Basis(X, lean * 0.5 - breath + chest_back) * Basis(Y, tw * 0.4) * Basis(Z, cz))
	_rot(I_NECK, Basis(X, -lean * 0.4))
	_rot(I_HEAD, Basis(X, head_x) * Basis(Y, head_y) * Basis(Z, idle * 0.015 * (1.0 - a)))
	# руки
	var arm_swing := s * 0.85 * a
	var sway := idle * 0.03
	var elbow := 0.18 + run * 0.9 * a + a * 0.1
	var wp := arm_swing + sway + rest_arm + 0.2
	if air:
		var u2 := clampf(vy / 7.0, -1.0, 1.0)
		_rot(I_ARM_P, Basis(X, -0.5 - maxf(0.0, u2) * 0.6) * Basis(Z, _zd(-(0.55 + (1.0 - maxf(0.0, u2)) * 0.15))))
		_rot(I_ARM_P + 1, Basis(X, -0.5))
		_rot(I_ARM_N, Basis(X, -0.5 - maxf(0.0, u2) * 0.6) * Basis(Z, _zd(0.55 + (1.0 - maxf(0.0, u2)) * 0.15)))
		_rot(I_ARM_N + 1, Basis(X, -0.5))
		wp = 0.9
	elif swinging and aim:
		_aim_pose(swing_angle)
		wp = swing_angle
	elif slam >= 0.0:
		_slam_pose(slam)
		wp = 0.2
	elif swinging and punch:
		_punch_pose(swing_angle)
		wp = 0.2
	elif swinging:
		_chop_pose(swing_angle)
		wp = swing_angle
	else:
		var fa := 0.0
		if fidget_e > 0.0 and fidget_k == 2:
			fa = sin(clampf(fidget_e / 1.8, 0.0, 1.0) * PI) * 0.7
		var sx := -fl * 0.5
		var lo := lower
		var el := elbow
		if swagger:
			lo = lower * (0.97 + 0.08 * run) - sin(t * 0.7 + rnd) * 0.03 * (1.0 - a)
			el = lerpf(0.5, 1.6, run * a) + 0.1 * (1.0 - a)    # ходьба ~30°, бег ~90°+ (по референсу)
			arm_swing = s * a * lerpf(0.45, 0.85, run) + 0.1 * run * a - 0.1 * (1.0 - a)
		_rot(I_ARM_P, Basis(X, arm_swing + sway - fa + sx) * Basis(Z, _zd(-lo + fl * 0.4)))
		var ef_p := (0.8 + 0.2 * maxf(0.0, -s)) if swagger else (0.6 + 0.4 * maxf(0.0, -s))
		var ef_n := (0.8 + 0.2 * maxf(0.0, s)) if swagger else (0.6 + 0.4 * maxf(0.0, s))
		_rot(I_ARM_P + 1, Basis(X, -el * ef_p))
		_rot(I_ARM_N, Basis(X, -arm_swing - sway - fa * 0.5 + sx) * Basis(Z, _zd(lo - fl * 0.4)))
		_rot(I_ARM_N + 1, Basis(X, -el * ef_n - (0.0 if swagger else 0.15)))
		if swagger:
			_rot(I_ARM_P + 2, Basis(Y, -1.3 * (0.4 + run)))      # кисть боком, а не ладонью вверх
			_rot(I_ARM_N + 2, Basis(Y, 1.3 * (0.4 + run)))
	if rage and not swinging and slam < 0.0 and not air and seat < 0.1:
		_guard_pose(idle)
	if seat > 0.01:
		_seat_pose(seat)
	if lean_in > 0.01:
		_lean_pose(lean_in, pull)
	if glow > 0.0 or rage:
		var g := clampf(glow, 0.0, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.12, 0.05)
		mat.emission_energy_multiplier = 0.06 + 0.16 * g
		mat.albedo_color = Color(1.0, 1.0 - 0.28 * g, 1.0 - 0.32 * g)
	elif mat.emission_enabled:
		mat.emission_enabled = false
		mat.albedo_color = Color.WHITE
	# бег Тревора: цикл подогнан по кадрам референса (tools: fit/*.py), поверх обычной позы
	if swagger and a > 0.05 and not air and not swinging and slam < 0.0 and seat < 0.01 and lean_in < 0.01 and not rage and crouch < 0.01:
		_cycle(WalkCycle, smoothstep(0.05, 0.9, a), tw)
		if run > 0.02:
			_cycle(RunCycle, smoothstep(0.0, 0.6, run), tw)
	_apply(delta, 30.0 if (swinging or slam >= 0.0) else 18.0)
	_update_weapon(wp)


func _cycle(tbl: GDScript, w: float, tw: float) -> void:
	var n: int = tbl.N
	var u := fposmod(phase / TAU * float(n) + tbl.PHASE_OFF, float(n))
	var i0 := int(u) % n
	var i1 := (i0 + 1) % n
	var f := u - floorf(u)
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3.BACK
	var d: Array = tbl.DATA
	# разворот таза и встречный разворот плеч: идёт от самой ноги (бедро вперёд -> таз вперёд)
	var th_p := lerpf(float(d[i0 * 16 + 9]), float(d[i1 * 16 + 9]), f)
	var th_n := lerpf(float(d[i0 * 16 + 12]), float(d[i1 * 16 + 12]), f)
	var lead := (th_n - th_p) * 0.5
	for k in tbl.BONES.size():
		var ang := lerpf(float(d[i0 * 16 + k]), float(d[i1 * 16 + k]), f)
		var bi: int = tbl.BONES[k]
		var b := Basis(X, ang)
		if bi == I_ARM_P:
			b = b * Basis(Z, _zd(-lower) - tbl.ARM_IN)
		elif bi == I_ARM_N:
			b = b * Basis(Z, _zd(lower) + tbl.ARM_IN)
		elif bi == I_THIGH_P:
			b = b * Basis(Z, -tbl.LEG_IN)
		elif bi == I_THIGH_N:
			b = b * Basis(Z, tbl.LEG_IN)
		elif bi == I_HIPS:
			b = b * Basis(Y, -tbl.TW_H * lead)
		elif bi == I_SPINE or bi == I_CHEST:
			b = b * Basis(Y, tbl.TW_S * lead)
		var q: Quaternion = b.get_rotation_quaternion()
		tgt[bi] = (tgt[bi] as Quaternion).slerp(q, w)
	var bob := lerpf(float(d[i0 * 16 + 15]), float(d[i1 * 16 + 15]), f)
	position.y = lerpf(position.y, bob, w)

func _aim_pose(p: float) -> void:
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3.BACK
	var fwd := clampf(p, 0.0, 2.2)
	var kick := clampf(p - 1.5, 0.0, 1.0)
	_rot(I_ARM_N, Basis(X, -fwd * 0.98) * Basis(Z, _zd(1.5)))
	_rot(I_ARM_N + 1, Basis(X, -0.1 + kick * 0.3))
	_rot(I_ARM_P, Basis(X, -fwd * 0.9) * Basis(Z, _zd(-1.38)))
	_rot(I_ARM_P + 1, Basis(X, -0.25) * Basis(Z, -0.5))
	_rot(I_SPINE, Basis(X, kick * 0.15) * Basis(Y, 0.18))
	_rot(I_CHEST, Basis(X, kick * 0.2) * Basis(Y, 0.15))
	_rot(I_HEAD, Basis(Y, -0.2) * Basis(X, -kick * 0.2))


func _blend(i: int, b: Basis, w: float) -> void:
	tgt[i] = (tgt[i] as Quaternion).slerp(b.get_rotation_quaternion(), clampf(w, 0.0, 1.0))


func _seat_pose(k: float) -> void:
	var X := Vector3.RIGHT
	var Z := Vector3.BACK
	_blend(I_THIGH_P, Basis(X, -1.5) * Basis(Z, -0.05), k)
	_blend(I_THIGH_N, Basis(X, -1.5) * Basis(Z, 0.05), k)
	_blend(I_THIGH_P + 1, Basis(X, 1.5), k)
	_blend(I_THIGH_N + 1, Basis(X, 1.5), k)
	_blend(I_ARM_P, Basis(X, -1.1) * Basis(Z, _zd(-1.7)), k)
	_blend(I_ARM_N, Basis(X, -1.1) * Basis(Z, _zd(1.7)), k)
	_blend(I_ARM_P + 1, Basis(X, -0.45), k)
	_blend(I_ARM_N + 1, Basis(X, -0.45), k)
	_blend(I_SPINE, Basis(X, -0.05), k)
	_blend(I_CHEST, Basis(X, 0.05), k)


func _lean_pose(k: float, pl: float) -> void:
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3.BACK
	# наклон в салон, потом рывок назад
	var sp := lerpf(-0.85, 0.1, pl)
	_blend(I_SPINE, Basis(X, sp * 0.6) * Basis(Y, 0.15), k)
	_blend(I_CHEST, Basis(X, sp * 0.5), k)
	_blend(I_HEAD, Basis(X, -sp * 0.3 + 0.2), k)
	var ax := lerpf(-1.35, -0.55, pl)
	_blend(I_ARM_P, Basis(X, ax) * Basis(Z, _zd(-1.65)), k)
	_blend(I_ARM_N, Basis(X, ax) * Basis(Z, _zd(1.65)), k)
	_blend(I_ARM_P + 1, Basis(X, lerpf(-0.25, -1.1, pl)), k)
	_blend(I_ARM_N + 1, Basis(X, lerpf(-0.25, -1.1, pl)), k)
	_blend(I_THIGH_P, Basis(X, 0.35 * (1.0 - pl) - 0.25 * pl), k)
	_blend(I_THIGH_N, Basis(X, -0.45 * (1.0 - pl) + 0.2 * pl), k)
	_blend(I_THIGH_P + 1, Basis(X, 0.2), k)
	_blend(I_THIGH_N + 1, Basis(X, 0.35), k)


func _guard_pose(idle: float) -> void:
	# боевая стойка: кулаки у лица, корпус вперёд, дышит тяжело
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3.BACK
	var br := idle * 0.05
	_blend(I_ARM_P, Basis(X, -0.95 + br) * Basis(Z, _zd(-1.75)), 0.85)
	_blend(I_ARM_N, Basis(X, -1.05 - br) * Basis(Z, _zd(1.75)), 0.85)
	_blend(I_ARM_P + 1, Basis(X, -1.9), 0.85)
	_blend(I_ARM_N + 1, Basis(X, -1.9), 0.85)
	_blend(I_SPINE, Basis(X, 0.18 + br) * Basis(Y, 0.25), 0.8)
	_blend(I_CHEST, Basis(X, 0.15) * Basis(Y, 0.15), 0.8)
	_blend(I_HEAD, Basis(X, -0.2) * Basis(Y, -0.3), 0.8)


func _slam_pose(k: float) -> void:
	# k: 0..0.45 — замах обеими руками над головой, 0.45..0.6 — удар в землю, дальше отдых
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3.BACK
	var up := smoothstep(0.0, 0.45, k) * (1.0 - smoothstep(0.45, 0.58, k))
	var hit := smoothstep(0.45, 0.58, k) * (1.0 - smoothstep(0.8, 1.0, k))
	var a := -3.0 * up - 0.7 * hit
	_rot(I_ARM_P, Basis(X, a) * Basis(Z, _zd(-1.55)))
	_rot(I_ARM_N, Basis(X, a) * Basis(Z, _zd(1.55)))
	_rot(I_ARM_P + 1, Basis(X, -0.3 * up))
	_rot(I_ARM_N + 1, Basis(X, -0.3 * up))
	_rot(I_SPINE, Basis(X, -0.25 * up + 0.5 * hit))
	_rot(I_CHEST, Basis(X, -0.2 * up + 0.4 * hit))
	_rot(I_HEAD, Basis(X, 0.2 * up - 0.3 * hit))
	_rot(I_THIGH_P, Basis(X, -0.7 * hit))
	_rot(I_THIGH_N, Basis(X, -0.7 * hit))
	_rot(I_THIGH_P + 1, Basis(X, 1.3 * hit))
	_rot(I_THIGH_N + 1, Basis(X, 1.3 * hit))
	position.y = -0.3 * hit


func _punch_pose(p: float) -> void:
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var Z := Vector3.BACK
	var ext := clampf((p - 0.2) / 2.7, 0.0, 1.0)
	if attack_kind == 1:
		# левый «кросс» — правая рука, корпус довернут
		_rot(I_ARM_P, Basis(X, -ext * 1.5 - 0.5) * Basis(Z, _zd(-1.5 + ext * 0.1)))
		_rot(I_ARM_P + 1, Basis(X, -1.6 * (1.0 - ext) - 0.05) * Basis(Z, -0.4 * (1.0 - ext)))
		_rot(I_ARM_N, Basis(X, -0.9) * Basis(Z, _zd(1.4)))
		_rot(I_ARM_N + 1, Basis(X, -1.5) * Basis(Z, 0.7))
		_rot(I_SPINE, Basis(X, -0.08) * Basis(Y, -0.6 * ext + 0.15))
		_rot(I_CHEST, Basis(X, -0.05) * Basis(Y, -0.45 * ext))
		_rot(I_HIPS, Basis(Y, -0.35 * ext + 0.1))
		_rot(I_HEAD, Basis(Y, 0.3 * ext))
		return
	if attack_kind == 2:
		# пинок ногой с разворотом
		_rot(I_THIGH_P, Basis(X, -1.55 * ext))
		_rot(I_THIGH_P + 1, Basis(X, 0.15 + 0.2 * (1.0 - ext)))
		_rot(I_THIGH_N, Basis(X, 0.15 * ext))
		_rot(I_THIGH_N + 1, Basis(X, 0.1))
		_rot(I_ARM_P, Basis(X, 0.2) * Basis(Z, _zd(-1.2)))
		_rot(I_ARM_N, Basis(X, 0.2) * Basis(Z, _zd(1.2)))
		_rot(I_ARM_P + 1, Basis(X, -0.3))
		_rot(I_ARM_N + 1, Basis(X, -0.3))
		_rot(I_SPINE, Basis(X, 0.3 * ext) * Basis(Y, 0.3 * ext))
		_rot(I_CHEST, Basis(X, 0.2 * ext))
		_rot(I_HIPS, Basis(Y, 0.4 * ext))
		_rot(I_HEAD, Basis(X, -0.2 * ext))
		return
	_rot(I_ARM_N, Basis(X, -ext * 1.5 - 0.5) * Basis(Z, _zd(1.5 - ext * 0.1)))
	_rot(I_ARM_N + 1, Basis(X, -1.6 * (1.0 - ext) - 0.05) * Basis(Z, 0.4 * (1.0 - ext)))
	_rot(I_ARM_P, Basis(X, -0.9) * Basis(Z, _zd(-1.4)))
	_rot(I_ARM_P + 1, Basis(X, -1.5) * Basis(Z, -0.7))
	_rot(I_SPINE, Basis(X, -0.08) * Basis(Y, 0.55 * ext - 0.15))
	_rot(I_CHEST, Basis(X, -0.05) * Basis(Y, 0.4 * ext))
	_rot(I_HIPS, Basis(Y, 0.3 * ext - 0.1))
	_rot(I_HEAD, Basis(Y, -0.3 * ext))


func _chop_pose(p: float) -> void:
	# swing_angle: 0.2 — опущен, ~2.9 — замах над головой, 1.15 — удар
	var X := Vector3.RIGHT
	var Y := Vector3.UP
	var up := clampf((p - 0.2) / 2.7, 0.0, 1.0)
	var fwd := clampf(p, 0.0, 2.6)
	_rot(I_ARM_N, Basis(X, -fwd * 0.9) * Basis(Vector3.BACK, _zd(1.5)))
	_rot(I_ARM_N + 1, Basis(X, -0.2 - up * 0.7) * Basis(Vector3.BACK, 0.55))
	_rot(I_ARM_P, Basis(X, -fwd * 0.85) * Basis(Vector3.BACK, _zd(-1.5)))
	_rot(I_ARM_P + 1, Basis(X, -0.3 - up * 0.7) * Basis(Vector3.BACK, -0.55))
	var tilt := (up - 0.45) * 0.8
	_rot(I_SPINE, Basis(X, tilt * 0.5) * Basis(Y, -0.25 * (1.0 - up)))
	_rot(I_CHEST, Basis(X, tilt * 0.7) * Basis(Y, -0.2 * (1.0 - up)))
	_rot(I_NECK, Basis(X, -tilt * 0.3))
	_rot(I_HEAD, Basis(X, -tilt * 0.4))

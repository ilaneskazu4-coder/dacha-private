class_name Club3D
extends Node3D
## Интерьер клуба «Розовый Енот»: зал 24 x 18 м, сцена, бар, диско-шар, лучи, конфетти.
## Координаты локальные: север (сцена) — это -Z, выход — на юге (+Z).

const HALF_X := 12.0
const HALF_Z := 9.0

var t := 0.0
var active := false
var lights: Array = []
var beams: Array = []
var ball: Node3D
var confetti: Array = []
var neon: Label3D


func _ready() -> void:
	_build_room()
	_build_stage()
	_build_bar()
	_build_furniture()
	_build_lights()
	_build_confetti()


func _wall(size: Vector3, pos: Vector3, col: Color) -> void:
	MeshKit.inst([MeshKit.box(size, Vector3.ZERO, col)], self, pos)
	MeshKit.static_box(self, size, pos)


func _build_room() -> void:
	# пол-шахматка
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(HALF_X * 2, HALF_Z * 2)
	floor_mi.mesh = pm
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color("34174a"))
	img.set_pixel(1, 1, Color("34174a"))
	img.set_pixel(1, 0, Color("1d0b2b"))
	img.set_pixel(0, 1, Color("1d0b2b"))
	var tex := ImageTexture.create_from_image(img)
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = tex
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fm.uv1_scale = Vector3(12, 9, 1)
	fm.roughness = 0.35
	fm.metallic_specular = 0.8
	floor_mi.material_override = fm
	add_child(floor_mi)
	MeshKit.static_box(self, Vector3(HALF_X * 2 + 4, 1, HALF_Z * 2 + 4), Vector3(0, -0.5, 0))
	# стены и потолок
	var wc := Color("3a1a4e")
	_wall(Vector3(HALF_X * 2 + 1, 5.2, 0.5), Vector3(0, 2.6, -HALF_Z - 0.25), wc)
	_wall(Vector3(HALF_X * 2 + 1, 5.2, 0.5), Vector3(0, 2.6, HALF_Z + 0.25), wc)
	_wall(Vector3(0.5, 5.2, HALF_Z * 2), Vector3(-HALF_X - 0.25, 2.6, 0), wc)
	_wall(Vector3(0.5, 5.2, HALF_Z * 2), Vector3(HALF_X + 0.25, 2.6, 0), wc)
	MeshKit.inst([MeshKit.box(Vector3(HALF_X * 2 + 1, 0.3, HALF_Z * 2 + 1), Vector3.ZERO, Color("160a20"))], self, Vector3(0, 5.3, 0))
	# пилястры и плинтус
	var pil: Array = []
	for i in 7:
		var x := -10.0 + i * 3.33
		pil.append(MeshKit.box(Vector3(0.5, 5.0, 0.3), Vector3(x, 2.5, HALF_Z - 0.15), Color("4a2a62")))
		pil.append(MeshKit.box(Vector3(0.5, 5.0, 0.3), Vector3(x, 2.5, -HALF_Z + 0.15), Color("4a2a62")))
	pil.append(MeshKit.box(Vector3(HALF_X * 2, 0.25, 0.2), Vector3(0, 0.12, HALF_Z - 0.1), Color("0c0612")))
	MeshKit.inst(pil, self)
	# выход
	MeshKit.inst([MeshKit.box(Vector3(3.2, 3.2, 0.2), Vector3(0, 1.6, HALF_Z - 0.08), Color("0c0612")),
		MeshKit.box(Vector3(3.5, 0.2, 0.25), Vector3(0, 3.3, HALF_Z - 0.1), Color("d4a93a"))], self)
	var ex := MeshKit.label("ВЫХОД", Vector3(0, 3.8, HALF_Z - 0.3), Color("3aff8a"), 64, 0.01, false, self)
	ex.rotation.y = PI
	ex.shaded = false
	# неон на стене над сценой
	neon = MeshKit.label("ДИСКО ЕНОТ", Vector3(0, 4.2, -HALF_Z + 0.4), Color("ff5fb0"), 110, 0.012, false, self)
	neon.shaded = false
	neon.outline_size = 36
	neon.outline_modulate = Color(1, 0.2, 0.6, 0.45)


func _build_stage() -> void:
	var parts: Array = [
		MeshKit.box(Vector3(12, 0.9, 4.6), Vector3(0, 0.45, -6.7), Color("5a2a3a")),
		MeshKit.box(Vector3(12.2, 0.12, 0.3), Vector3(0, 0.92, -4.45), Color("e8c23a")),
		MeshKit.box(Vector3(12, 0.1, 4.6), Vector3(0, 0.95, -6.7), Color("7a3a4a"))]
	# занавесы
	for s in [-1, 1]:
		parts.append(MeshKit.box(Vector3(1.8, 4.6, 0.4), Vector3(s * 6.4, 2.6, -8.4), Color("a01a3a")))
		parts.append(MeshKit.box(Vector3(1.0, 4.4, 0.4), Vector3(s * 5.2, 2.7, -8.5), Color("c0243f")))
	parts.append(MeshKit.box(Vector3(14.5, 0.8, 0.5), Vector3(0, 4.7, -8.3), Color("a01a3a")))
	MeshKit.inst(parts, self)
	MeshKit.static_box(self, Vector3(12, 0.9, 4.6), Vector3(0, 0.45, -6.7))
	var bulbs: Array = []
	for i in 13:
		bulbs.append(MeshKit.sph(0.1, Vector3(-5.8 + i * 0.97, 1.05, -4.42), Color.WHITE, Vector3.ONE, 6))
	MeshKit.glow_inst(bulbs, Color("ffe08a"), self, 2.0)
	# диско-шар
	ball = Node3D.new()
	ball.position = Vector3(0, 4.0, -1.5)
	add_child(ball)
	MeshKit.inst([MeshKit.cyl(0.02, 0.02, 1.3, Vector3(0, 0.9, 0), Color("888888"), Vector3.ZERO, 4)], ball)
	var bm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.55
	sm.height = 1.1
	sm.radial_segments = 16
	sm.rings = 8
	bm.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color("c8ccd8")
	mm.metallic = 1.0
	mm.roughness = 0.15
	mm.emission_enabled = true
	mm.emission = Color("8890a8")
	mm.emission_energy_multiplier = 0.6
	bm.material_override = mm
	ball.add_child(bm)


func _build_bar() -> void:
	var parts: Array = [
		MeshKit.box(Vector3(1.4, 1.1, 7.0), Vector3(-9.8, 0.55, -1.0), Color("4a2a1a")),
		MeshKit.box(Vector3(1.7, 0.12, 7.3), Vector3(-9.8, 1.15, -1.0), Color("8a6a48")),
		MeshKit.box(Vector3(0.4, 2.4, 7.0), Vector3(-11.8, 1.3, -1.0), Color("2a1a3a")),
		MeshKit.box(Vector3(0.06, 0.1, 7.0), Vector3(-11.55, 2.0, -1.0), Color("8a6a48")),
		MeshKit.box(Vector3(0.06, 0.1, 7.0), Vector3(-11.55, 2.6, -1.0), Color("8a6a48"))]
	for i in 12:
		var z := -4.2 + i * 0.58
		parts.append(MeshKit.cyl(0.07, 0.07, 0.4, Vector3(-11.5, 2.2, z), Color.from_hsv(i / 12.0, 0.6, 0.9), Vector3.ZERO, 6))
		parts.append(MeshKit.cyl(0.07, 0.07, 0.4, Vector3(-11.5, 2.8, z + 0.2), Color.from_hsv(fmod(i / 12.0 + 0.5, 1.0), 0.6, 0.9), Vector3.ZERO, 6))
	for i in 5:
		parts.append(MeshKit.cyl(0.22, 0.22, 0.05, Vector3(-8.3, 0.7, -3.5 + i * 1.5), Color("a01a3a"), Vector3.ZERO, 10))
		parts.append(MeshKit.cyl(0.04, 0.04, 0.7, Vector3(-8.3, 0.35, -3.5 + i * 1.5), Color("888888"), Vector3.ZERO, 6))
	MeshKit.inst(parts, self)
	MeshKit.static_box(self, Vector3(1.7, 1.2, 7.3), Vector3(-9.8, 0.6, -1.0))


func _build_furniture() -> void:
	var parts: Array = []
	var candles: Array = []
	for p: Vector2 in [Vector2(-5, 3), Vector2(5, 2), Vector2(8, 6), Vector2(-7, 6.5)]:
		parts.append(MeshKit.cyl(0.8, 0.8, 0.08, Vector3(p.x, 1.0, p.y), Color("6a3a4a"), Vector3.ZERO, 14))
		parts.append(MeshKit.cyl(0.09, 0.09, 1.0, Vector3(p.x, 0.5, p.y), Color("2a1a2a"), Vector3.ZERO, 6))
		parts.append(MeshKit.cyl(0.4, 0.4, 0.06, Vector3(p.x, 0.03, p.y), Color("2a1a2a"), Vector3.ZERO, 8))
		candles.append(MeshKit.sph(0.07, Vector3(p.x, 1.14, p.y), Color.WHITE, Vector3(1, 1.5, 1), 6))
		for k in 2:
			var a: float = k * PI + p.x
			parts.append(MeshKit.cyl(0.22, 0.22, 0.08, Vector3(p.x + cos(a) * 1.3, 0.6, p.y + sin(a) * 1.3), Color("a01a3a"), Vector3.ZERO, 8))
			parts.append(MeshKit.cyl(0.04, 0.04, 0.55, Vector3(p.x + cos(a) * 1.3, 0.3, p.y + sin(a) * 1.3), Color("888888"), Vector3.ZERO, 5))
		MeshKit.static_cyl(self, 0.95, 1.2, Vector3(p.x, 0.6, p.y))
	# VIP-диван
	parts.append(MeshKit.box(Vector3(2.0, 0.55, 5.2), Vector3(10.6, 0.28, -3.6), Color("7a1a3a")))
	parts.append(MeshKit.box(Vector3(0.6, 1.4, 5.2), Vector3(11.5, 0.7, -3.6), Color("9a2a4a")))
	parts.append(MeshKit.box(Vector3(0.5, 0.9, 5.2), Vector3(10.0, 0.45, -3.6), Color("9a2a4a")))
	MeshKit.static_box(self, Vector3(2.4, 1.2, 5.2), Vector3(10.8, 0.6, -3.6))
	MeshKit.inst(parts, self)
	MeshKit.glow_inst(candles, Color("ffcf70"), self, 3.0)
	var vip := MeshKit.label("VIP", Vector3(11.7, 2.7, -3.6), Color("ffd23a"), 80, 0.012, false, self)
	vip.rotation.y = -PI / 2
	vip.shaded = false


func _build_lights() -> void:
	var cols := [Color("ff3a8a"), Color("3a8aff"), Color("3aff8a"), Color("ffcf3a")]
	for i in 4:
		var l := OmniLight3D.new()
		l.light_color = cols[i]
		l.omni_range = 11.0
		l.light_energy = 2.0
		l.position = Vector3(0, 3.8, 0)
		add_child(l)
		lights.append(l)
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bmat.albedo_color = Color(1, 1, 1, 0.16)
	for i in 6:
		var piv := Node3D.new()
		piv.position = Vector3(-10.0 + i * 4.0, 5.1, -7.8)
		add_child(piv)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.04
		cm.bottom_radius = 1.0
		cm.height = 7.0
		cm.radial_segments = 14
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		mi.mesh = cm
		mi.position = Vector3(0, -3.5, 0)
		var m := bmat.duplicate() as StandardMaterial3D
		mi.material_override = m
		piv.add_child(mi)
		beams.append([piv, m])


func _build_confetti() -> void:
	var cols := [Color("ffd23a"), Color("ff5fb0"), Color("4fd0ff")]
	for c in cols:
		var p := CPUParticles3D.new()
		p.position = Vector3(0, 4.0, -3.0)
		p.amount = 70
		p.lifetime = 3.2
		p.one_shot = true
		p.emitting = false
		p.explosiveness = 0.9
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(4.0, 0.2, 1.5)
		p.direction = Vector3(0, -0.3, 0)
		p.spread = 70.0
		p.initial_velocity_min = 1.0
		p.initial_velocity_max = 4.0
		p.gravity = Vector3(0, -3.0, 0)
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		var bm := BoxMesh.new()
		bm.size = Vector3(0.14, 0.02, 0.09)
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		bm.material = m
		p.mesh = bm
		add_child(p)
		confetti.append(p)


func rain() -> void:
	for p in confetti:
		p.restart()
		p.emitting = true


func _process(delta: float) -> void:
	if not active:
		return
	t += delta
	for i in lights.size():
		var l: OmniLight3D = lights[i]
		var a := t * (0.6 + i * 0.15) + i * 1.6
		l.position = Vector3(cos(a) * 8.0, 3.6, sin(a * 1.3) * 5.0)
		l.light_color = Color.from_hsv(fmod(t * 0.1 + i * 0.25, 1.0), 0.85, 1.0)
	for i in beams.size():
		var piv: Node3D = beams[i][0]
		var m: StandardMaterial3D = beams[i][1]
		piv.rotation = Vector3(sin(t * 1.2 + i * 1.3) * 0.7, 0.0, cos(t * 0.9 + i * 0.8) * 0.7)
		var c := Color.from_hsv(fmod(t * 0.12 + i * 0.17, 1.0), 0.8, 1.0, 0.15)
		m.albedo_color = c
	ball.rotation.y += delta * 1.2
	neon.modulate = Color(1.0, 0.35 + 0.25 * sin(t * 3.0), 0.75)

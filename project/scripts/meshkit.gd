class_name MeshKit
extends RefCounted
## Сборка 3D-моделей из примитивов: части склеиваются в один меш с цветом вершин.
## Одна модель = один вызов отрисовки, это важно для телефонов.

static var _mat: StandardMaterial3D
static var _glow := {}
static var _detail_tex: ImageTexture
static var _detail_nrm: ImageTexture
static var detail_level := -1


static func mat() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.vertex_color_is_srgb = true
		_mat.roughness = 0.9
	return _mat


## Мелкая «фактура» поверх цвета вершин: процедурный шум в мировых координатах.
## 0 — выключено, 1 — зернистость, 2 — зернистость и рельеф (нормали).
static func set_detail(level: int) -> void:
	if level == detail_level:
		return
	detail_level = level
	var m := mat()
	if level <= 0:
		m.albedo_texture = null
		m.normal_enabled = false
		m.normal_texture = null
		return
	if _detail_tex == null:
		_make_detail()
	m.albedo_texture = _detail_tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.32, 0.32, 0.32)
	m.uv1_triplanar_sharpness = 3.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if level >= 2:
		m.normal_enabled = true
		m.normal_texture = _detail_nrm
		m.normal_scale = 0.7
	else:
		m.normal_enabled = false
		m.normal_texture = null


static func _make_detail() -> void:
	var n1 := FastNoiseLite.new()
	n1.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n1.frequency = 0.035
	n1.fractal_octaves = 3
	var n2 := FastNoiseLite.new()
	n2.noise_type = FastNoiseLite.TYPE_CELLULAR
	n2.frequency = 0.07
	n2.seed = 9
	var n3 := FastNoiseLite.new()
	n3.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n3.frequency = 0.22
	n3.seed = 4
	var sz := 128
	var a := n1.get_seamless_image(sz, sz, false, false, 0.2, true)
	var b := n2.get_seamless_image(sz, sz, false, false, 0.2, true)
	var c := n3.get_seamless_image(sz, sz, false, false, 0.2, true)
	var alb := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var bump := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in sz:
		for x in sz:
			var v1 := a.get_pixel(x, y).r
			var v2 := b.get_pixel(x, y).r
			var v3 := c.get_pixel(x, y).r
			var g := clampf(0.80 + (v1 - 0.5) * 0.30 + (v2 - 0.5) * 0.22 + (v3 - 0.5) * 0.16, 0.45, 1.0)
			alb.set_pixel(x, y, Color(g, g, g * 0.985, 1.0))
			var h := clampf(v2 * 0.6 + v3 * 0.4, 0.0, 1.0)
			bump.set_pixel(x, y, Color(h, h, h, 1.0))
	alb.generate_mipmaps()
	_detail_tex = ImageTexture.create_from_image(alb)
	bump.bump_map_to_normal_map(3.0)
	bump.generate_mipmaps()
	_detail_nrm = ImageTexture.create_from_image(bump)


static func glow_mat(col: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "%s_%s" % [col.to_html(), energy]
	if not _glow.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = energy
		m.roughness = 0.6
		_glow[key] = m
	return _glow[key]


# ---------- части: [меш, трансформ, цвет] ----------

static func box(size: Vector3, pos: Vector3 = Vector3.ZERO, col: Color = Color.WHITE, rot: Vector3 = Vector3.ZERO) -> Array:
	var m := BoxMesh.new()
	m.size = size
	return [m, Transform3D(Basis.from_euler(rot), pos), col]


static func cyl(rt: float, rb: float, h: float, pos: Vector3 = Vector3.ZERO, col: Color = Color.WHITE,
		rot: Vector3 = Vector3.ZERO, seg: int = 12) -> Array:
	var m := CylinderMesh.new()
	m.top_radius = rt
	m.bottom_radius = rb
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return [m, Transform3D(Basis.from_euler(rot), pos), col]


static func sph(r: float, pos: Vector3 = Vector3.ZERO, col: Color = Color.WHITE,
		scl: Vector3 = Vector3.ONE, seg: int = 12) -> Array:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = maxi(4, seg / 2)
	return [m, Transform3D(Basis.from_scale(scl), pos), col]


static func prism(size: Vector3, pos: Vector3 = Vector3.ZERO, col: Color = Color.WHITE, rot: Vector3 = Vector3.ZERO) -> Array:
	var m := PrismMesh.new()
	m.size = size
	return [m, Transform3D(Basis.from_euler(rot), pos), col]


# ---------- сборка ----------

static func build(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for p in parts:
		var m: PrimitiveMesh = p[0]
		var xf: Transform3D = p[1]
		var c: Color = p[2]
		var a: Array = m.get_mesh_arrays()
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var ix: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var base := verts.size()
		var nb := xf.basis.inverse().transposed()
		for i in v.size():
			verts.append(xf * v[i])
			norms.append((nb * n[i]).normalized())
			cols.append(c)
		if ix.is_empty():
			for i in v.size():
				idx.append(base + i)
		else:
			for i in ix:
				idx.append(base + i)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func inst(parts: Array, parent: Node = null, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = build(parts)
	mi.material_override = mat()
	mi.position = pos
	if parent != null:
		parent.add_child(mi)
	return mi


static func glow_inst(parts: Array, col: Color, parent: Node = null, energy: float = 2.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var white: Array = []
	for p in parts:
		white.append([p[0], p[1], Color.WHITE])
	mi.mesh = build(white)
	mi.material_override = glow_mat(col, energy)
	if parent != null:
		parent.add_child(mi)
	return mi


static func static_box(parent: Node, size: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.position = pos
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


static func static_cyl(parent: Node, r: float, h: float, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	sb.position = pos
	sb.add_child(cs)
	parent.add_child(sb)
	return sb


static func label(text: String, pos: Vector3, col: Color, font_size: int = 48, pixel: float = 0.01,
		billboard: bool = false, parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.modulate = col
	l.font_size = font_size
	l.pixel_size = pixel
	l.outline_size = 10
	l.outline_modulate = Color(0, 0, 0, 0.9)
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.render_priority = 5
	if parent != null:
		parent.add_child(l)
	return l

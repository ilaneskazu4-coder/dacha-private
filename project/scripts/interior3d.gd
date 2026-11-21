class_name Interior3D
extends Node3D
## Интерьер дома. Локальные координаты: центр комнаты в (0,0,0), дверь на юге (+Z).
## points: интерактивные точки {pos: Vector3, r: float, id: String, label: String}.

const H := 3.1

var kind := ""
var hx := 5.0
var hz := 4.0
var points: Array = []
var npc_spots: Array = []     # куда встают жители, когда уходят домой на ночь
var light: OmniLight3D
var cat: Node3D
var t := 0.0

const SPEC := {
	"home":   {"w": 11.0, "d": 9.0, "wall": "d9c49a", "floor": "9b6b3f", "title": "Дача Михалыча"},
	"shed":   {"w": 10.0, "d": 8.0, "wall": "8a929c", "floor": "6a6f78", "title": "Сарай"},
	"makar":  {"w": 10.0, "d": 8.0, "wall": "b9c7a0", "floor": "7a5a38", "title": "Дом деда Макара"},
	"lyuda":  {"w": 10.0, "d": 8.0, "wall": "e8c6d4", "floor": "a9774a", "title": "Дом бабы Люды"},
	"bytovka": {"w": 8.0, "d": 7.0, "wall": "9fb4c9", "floor": "5a5f66", "title": "Бытовка Коли"},
	"shop":   {"w": 12.0, "d": 8.0, "wall": "f0e6c8", "floor": "8a8f98", "title": "Магазин «Сельпо»"},
}


static func size_of(k: String) -> Vector2:
	var s: Dictionary = SPEC[k]
	return Vector2(float(s["w"]), float(s["d"]))


func setup(k: String) -> void:
	kind = k
	var s: Dictionary = SPEC[k]
	hx = float(s["w"]) / 2.0
	hz = float(s["d"]) / 2.0
	_shell(Color(String(s["wall"])), Color(String(s["floor"])))
	_light()
	match k:
		"home": _home()
		"shed": _shed()
		"makar": _makar()
		"lyuda": _lyuda()
		"bytovka": _bytovka()
		"shop": _shop()


func spawn_pos() -> Vector3:
	return Vector3(0, 0.05, hz - 1.6)


func in_exit(local: Vector3) -> bool:
	return local.z > hz - 1.1 and absf(local.x) < 1.6


func _wall(size: Vector3, pos: Vector3, col: Color) -> void:
	MeshKit.inst([MeshKit.box(size, Vector3.ZERO, col)], self, pos)
	MeshKit.static_box(self, size, pos)


func _shell(wall: Color, floor_col: Color) -> void:
	# пол — доски
	var parts: Array = []
	var n := int(hx * 2.0 / 0.5)
	for i in n:
		var c := floor_col.lightened(0.05 if i % 2 == 0 else -0.06)
		parts.append(MeshKit.box(Vector3(0.5, 0.1, hz * 2.0), Vector3(-hx + 0.25 + i * 0.5, -0.05, 0), c))
	MeshKit.inst(parts, self)
	MeshKit.static_box(self, Vector3(hx * 2 + 4, 1, hz * 2 + 4), Vector3(0, -0.55, 0))
	# стены
	_wall(Vector3(hx * 2 + 0.6, H, 0.3), Vector3(0, H / 2, -hz - 0.15), wall)
	_wall(Vector3(0.3, H, hz * 2), Vector3(-hx - 0.15, H / 2, 0), wall)
	_wall(Vector3(0.3, H, hz * 2), Vector3(hx + 0.15, H / 2, 0), wall)
	# южная стена с проёмом-дверью
	var sw := hx - 1.0
	_wall(Vector3(sw, H, 0.3), Vector3(-hx + sw / 2, H / 2, hz + 0.15), wall)
	_wall(Vector3(sw, H, 0.3), Vector3(hx - sw / 2, H / 2, hz + 0.15), wall)
	_wall(Vector3(2.0, H - 2.3, 0.3), Vector3(0, 2.3 + (H - 2.3) / 2, hz + 0.15), wall)
	# закрывающая «дверь» — тёмная панель, чтобы не видеть улицу; выход по триггеру
	MeshKit.inst([MeshKit.box(Vector3(2.0, 2.3, 0.1), Vector3.ZERO, Color("4a2d1c")),
		MeshKit.sph(0.07, Vector3(0.7, 0, 0.08), Color("d4a93a"), Vector3.ONE, 6)], self, Vector3(0, 1.15, hz - 0.02))
	MeshKit.static_box(self, Vector3(2.0, 2.3, 0.3), Vector3(0, 1.15, hz + 0.1))
	var ex := MeshKit.label("ВЫХОД", Vector3(0, 2.55, hz - 0.12), Color("ffe9a8"), 40, 0.007, false, self)
	ex.rotation.y = PI
	# потолок, балки, плинтус
	var cp: Array = [MeshKit.box(Vector3(hx * 2 + 0.6, 0.2, hz * 2 + 0.6), Vector3(0, H + 0.1, 0), wall.darkened(0.35))]
	for i in int(hx * 2.0 / 2.0):
		cp.append(MeshKit.box(Vector3(0.22, 0.22, hz * 2), Vector3(-hx + 1.0 + i * 2.0, H - 0.11, 0), Color("5a3b22")))
	cp.append(MeshKit.box(Vector3(hx * 2, 0.14, 0.06), Vector3(0, 0.07, -hz + 0.03), wall.darkened(0.4)))
	cp.append(MeshKit.box(Vector3(0.06, 0.14, hz * 2), Vector3(-hx + 0.03, 0.07, 0), wall.darkened(0.4)))
	cp.append(MeshKit.box(Vector3(0.06, 0.14, hz * 2), Vector3(hx - 0.03, 0.07, 0), wall.darkened(0.4)))
	MeshKit.inst(cp, self)
	MeshKit.static_box(self, Vector3(hx * 2 + 1, 0.4, hz * 2 + 1), Vector3(0, H + 0.2, 0))


func _light() -> void:
	light = OmniLight3D.new()
	light.position = Vector3(0, H - 0.5, 0)
	light.light_color = Color("ffd9a0")
	light.light_energy = 1.7
	light.omni_range = maxf(hx, hz) * 2.4
	add_child(light)
	# лампочка
	MeshKit.glow_inst([MeshKit.sph(0.14, Vector3(0, H - 0.4, 0), Color.WHITE, Vector3.ONE, 8)], Color("fff0c0"), self, 3.0)
	MeshKit.inst([MeshKit.cyl(0.01, 0.01, 0.35, Vector3(0, H - 0.2, 0), Color("222222"), Vector3.ZERO, 4)], self)


func _window(pos: Vector3, rot_y: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot_y
	add_child(n)
	MeshKit.inst([MeshKit.box(Vector3(1.5, 1.2, 0.06), Vector3.ZERO, Color("e8d9a0"))], n)
	MeshKit.glow_inst([MeshKit.box(Vector3(1.28, 0.98, 0.07), Vector3(0, 0, 0.01), Color("a9cdf2"))], Color("a9cdf2"), n, 0.9)
	MeshKit.inst([MeshKit.box(Vector3(0.05, 1.0, 0.09), Vector3.ZERO, Color("e8d9a0")),
		MeshKit.box(Vector3(1.3, 0.05, 0.09), Vector3.ZERO, Color("e8d9a0"))], n)


func _pt(pos: Vector3, r: float, id: String, label: String) -> void:
	points.append({"pos": pos, "r": r, "id": id, "label": label})


# ---------- мебель ----------

func _table(pos: Vector3, w: float = 1.8, d: float = 1.0, col: Color = Color("8a5a2b")) -> void:
	var p: Array = [MeshKit.box(Vector3(w, 0.1, d), Vector3(0, 0.82, 0), col)]
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			p.append(MeshKit.box(Vector3(0.1, 0.8, 0.1), Vector3(sx * (w / 2 - 0.1), 0.4, sz * (d / 2 - 0.1)), col.darkened(0.25)))
	MeshKit.inst(p, self, pos)
	MeshKit.static_box(self, Vector3(w, 0.9, d), pos + Vector3(0, 0.45, 0))


func _chair(pos: Vector3, yaw: float = 0.0, col: Color = Color("7a4a22")) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	var p: Array = [MeshKit.box(Vector3(0.5, 0.07, 0.5), Vector3(0, 0.5, 0), col),
		MeshKit.box(Vector3(0.5, 0.6, 0.06), Vector3(0, 0.82, -0.23), col)]
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			p.append(MeshKit.box(Vector3(0.06, 0.5, 0.06), Vector3(sx * 0.21, 0.25, sz * 0.21), col.darkened(0.3)))
	MeshKit.inst(p, n)


func _bed(pos: Vector3, yaw: float, blanket: Color, wide: float = 1.5) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	var p: Array = [MeshKit.box(Vector3(wide, 0.35, 2.1), Vector3(0, 0.3, 0), Color("6a4326")),
		MeshKit.box(Vector3(wide - 0.1, 0.22, 2.0), Vector3(0, 0.56, 0), Color("f2efe6")),
		MeshKit.box(Vector3(wide - 0.05, 0.12, 1.3), Vector3(0, 0.72, 0.35), blanket),
		MeshKit.box(Vector3(wide - 0.4, 0.14, 0.45), Vector3(0, 0.74, -0.7), Color("ffffff")),
		MeshKit.box(Vector3(wide, 0.9, 0.12), Vector3(0, 0.7, -1.05), Color("5a3a20"))]
	MeshKit.inst(p, n)
	MeshKit.static_box(n, Vector3(wide, 0.8, 2.1), Vector3(0, 0.4, 0))


func _shelf(pos: Vector3, yaw: float, w: float = 1.6, rows: int = 4, goods: bool = false) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	var p: Array = [MeshKit.box(Vector3(w, 2.0, 0.05), Vector3(0, 1.0, -0.2), Color("5a3b22")),
		MeshKit.box(Vector3(0.05, 2.0, 0.45), Vector3(-w / 2, 1.0, 0), Color("5a3b22")),
		MeshKit.box(Vector3(0.05, 2.0, 0.45), Vector3(w / 2, 1.0, 0), Color("5a3b22"))]
	var cols := [Color("d83a3a"), Color("e8c23a"), Color("3a9ad8"), Color("5ac85a"), Color("e8e8e8"), Color("d87a2a")]
	for r in rows:
		var y := 0.25 + r * 0.5
		p.append(MeshKit.box(Vector3(w, 0.05, 0.45), Vector3(0, y, 0), Color("6a4326")))
		var cnt := int(w / 0.28) if goods else int(w / 0.5)
		for i in cnt:
			var c: Color = cols[(i + r * 2) % cols.size()]
			if goods:
				p.append(MeshKit.box(Vector3(0.2, 0.28, 0.2), Vector3(-w / 2 + 0.2 + i * 0.28, y + 0.16, 0), c))
			else:
				p.append(MeshKit.cyl(0.09, 0.09, 0.26, Vector3(-w / 2 + 0.3 + i * 0.5, y + 0.16, 0), c, Vector3.ZERO, 7))
	MeshKit.inst(p, n)
	MeshKit.static_box(n, Vector3(w, 2.0, 0.5), Vector3(0, 1.0, 0))


func _stove(pos: Vector3, yaw: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	var p: Array = [MeshKit.box(Vector3(1.6, 1.3, 1.0), Vector3(0, 0.65, 0), Color("b5553c")),
		MeshKit.box(Vector3(1.7, 0.1, 1.1), Vector3(0, 1.32, 0), Color("6a2f22")),
		MeshKit.box(Vector3(0.7, 2.2, 0.7), Vector3(0, 2.2, -0.15), Color("a34a33"))]
	for i in 5:
		p.append(MeshKit.box(Vector3(1.6, 0.04, 1.02), Vector3(0, 0.15 + i * 0.26, 0), Color("8a3c28")))
	MeshKit.inst(p, n)
	MeshKit.glow_inst([MeshKit.box(Vector3(0.6, 0.4, 0.05), Vector3(0, 0.55, 0.51), Color("ff8a2a"))], Color("ff7a1a"), n, 2.4)
	MeshKit.static_box(n, Vector3(1.7, 1.4, 1.1), Vector3(0, 0.7, 0))
	var fl := OmniLight3D.new()
	fl.position = Vector3(0, 0.8, 0.9)
	fl.light_color = Color("ff8a3a")
	fl.light_energy = 0.9
	fl.omni_range = 5.0
	n.add_child(fl)


func _rug(pos: Vector3, w: float, d: float, c1: Color, c2: Color) -> void:
	MeshKit.inst([MeshKit.box(Vector3(w, 0.02, d), Vector3(0, 0.01, 0), c1),
		MeshKit.box(Vector3(w - 0.4, 0.025, d - 0.4), Vector3(0, 0.012, 0), c2)], self, pos)


func _chest(pos: Vector3, yaw: float = 0.0) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	MeshKit.inst([MeshKit.box(Vector3(0.9, 0.55, 0.55), Vector3(0, 0.28, 0), Color("6a4326")),
		MeshKit.box(Vector3(0.95, 0.12, 0.6), Vector3(0, 0.6, 0), Color("55361e")),
		MeshKit.box(Vector3(0.12, 0.2, 0.06), Vector3(0, 0.42, 0.3), Color("d4a93a"))], n)
	MeshKit.static_box(n, Vector3(0.9, 0.7, 0.55), Vector3(0, 0.35, 0))


func _frame(pos: Vector3, yaw: float, col: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	MeshKit.inst([MeshKit.box(Vector3(0.7, 0.55, 0.05), Vector3.ZERO, Color("4a3220")),
		MeshKit.box(Vector3(0.58, 0.43, 0.06), Vector3(0, 0, 0.01), col)], n)


func _lamp_floor(pos: Vector3) -> void:
	MeshKit.inst([MeshKit.cyl(0.03, 0.03, 1.4, Vector3(0, 0.7, 0), Color("333333"), Vector3.ZERO, 5),
		MeshKit.cyl(0.07, 0.25, 0.3, Vector3(0, 1.5, 0), Color("e8c88a"), Vector3.ZERO, 8),
		MeshKit.cyl(0.2, 0.2, 0.04, Vector3(0, 0.02, 0), Color("333333"), Vector3.ZERO, 8)], self, pos)


func _cat(pos: Vector3, col: Color) -> void:
	cat = Node3D.new()
	cat.position = pos
	add_child(cat)
	MeshKit.inst([MeshKit.box(Vector3(0.28, 0.24, 0.5), Vector3(0, 0.2, 0), col),
		MeshKit.sph(0.15, Vector3(0, 0.34, 0.3), col, Vector3.ONE, 8),
		MeshKit.box(Vector3(0.05, 0.1, 0.05), Vector3(-0.08, 0.5, 0.3), col),
		MeshKit.box(Vector3(0.05, 0.1, 0.05), Vector3(0.08, 0.5, 0.3), col),
		MeshKit.box(Vector3(0.05, 0.05, 0.4), Vector3(0, 0.3, -0.4), col, Vector3(0.6, 0, 0))], cat)


# ---------- наполнение ----------

func _home() -> void:
	_window(Vector3(-hx + 0.02, 1.7, -1.5), PI / 2)
	_window(Vector3(hx - 0.02, 1.7, -1.5), -PI / 2)
	_window(Vector3(-2.2, 1.7, -hz + 0.02), 0.0)
	_bed(Vector3(-hx + 1.3, 0, -hz + 1.6), 0.0, Color("b3261e"), 1.7)
	_stove(Vector3(hx - 1.6, 0, -hz + 0.7))
	_table(Vector3(0.5, 0, 0.3), 1.8, 1.0)
	_chair(Vector3(-0.5, 0, 0.3), -PI / 2)
	_chair(Vector3(1.5, 0, 0.3), PI / 2)
	_chair(Vector3(0.5, 0, 1.2), PI)
	_shelf(Vector3(1.2, 0, -hz + 0.35), 0.0, 2.0, 4)
	_chest(Vector3(-hx + 0.6, 0, 1.0), PI / 2)
	_rug(Vector3(0.5, 0, 0.4), 3.4, 2.6, Color("7a2a2a"), Color("c9a05a"))
	_lamp_floor(Vector3(-hx + 0.7, 0, hz - 0.8))
	_frame(Vector3(0, 2.0, -hz + 0.05), 0.0, Color("6aa0d8"))
	_frame(Vector3(-hx + 0.05, 2.0, 2.0), PI / 2, Color("d8b46a"))
	# радио на столе
	MeshKit.inst([MeshKit.box(Vector3(0.45, 0.28, 0.2), Vector3(0, 0.99, 0), Color("2a2a2a")),
		MeshKit.box(Vector3(0.2, 0.14, 0.02), Vector3(-0.08, 1.0, 0.11), Color("8ac8a0"))], self, Vector3(0.8, 0, 0.2))
	_pt(Vector3(-hx + 1.4, 0, -hz + 2.6), 1.9, "bed", "Отдохнуть")
	_pt(Vector3(-hx + 0.9, 0, 1.0), 1.5, "chest", "Открыть сундук")
	_pt(Vector3(0.8, 0, 0.9), 1.5, "radio", "Включить радио")
	npc_spots = [Vector3(1.5, 0, 1.6)]


func _shed() -> void:
	_window(Vector3(hx - 0.02, 1.8, -1.0), -PI / 2)
	# верстак
	_table(Vector3(-hx + 1.6, 0, -hz + 0.9), 2.6, 0.9, Color("6a5a40"))
	MeshKit.inst([MeshKit.box(Vector3(0.9, 0.12, 0.35), Vector3(0, 0.92, 0), Color("aab0b8")),
		MeshKit.box(Vector3(0.12, 0.5, 0.12), Vector3(0.4, 1.15, 0), Color("c9532a"))], self, Vector3(-hx + 1.4, 0, -hz + 0.9))
	# инструмент на стене
	var tools: Array = []
	for i in 5:
		tools.append(MeshKit.box(Vector3(0.08, 1.0, 0.04), Vector3(-0.9 + i * 0.45, 0, 0), Color("6b4423")))
		tools.append(MeshKit.box(Vector3(0.28, 0.22, 0.05), Vector3(-0.9 + i * 0.45, 0.55, 0), Color("c9ced6")))
	MeshKit.inst(tools, self, Vector3(1.0, 1.7, -hz + 0.06))
	_shelf(Vector3(hx - 1.2, 0, -hz + 0.35), 0.0, 1.8, 3)
	# канистры и бочка
	MeshKit.inst([MeshKit.cyl(0.4, 0.4, 1.0, Vector3(0, 0.5, 0), Color("a02020"), Vector3.ZERO, 10),
		MeshKit.cyl(0.4, 0.4, 1.0, Vector3(0.9, 0.5, 0.2), Color("2a5a9a"), Vector3.ZERO, 10),
		MeshKit.box(Vector3(0.4, 0.55, 0.2), Vector3(-0.8, 0.28, 0), Color("d8a020"))], self, Vector3(hx - 1.2, 0, 0.8))
	MeshKit.static_box(self, Vector3(2.2, 1.0, 0.9), Vector3(hx - 1.0, 0.5, 0.9))
	# запаска для Пассата
	MeshKit.inst([MeshKit.cyl(0.42, 0.42, 0.24, Vector3(0, 0.45, 0), Color("1a1a1a"), Vector3(PI / 2, 0, 0), 14),
		MeshKit.cyl(0.2, 0.2, 0.26, Vector3(0, 0.45, 0), Color("8a8f98"), Vector3(PI / 2, 0, 0), 8)], self, Vector3(-hx + 0.8, 0, 0.5))
	_chest(Vector3(-1.5, 0, -hz + 0.5))
	_rug(Vector3(0, 0, 0.3), 3.0, 2.0, Color("3a4048"), Color("5a626c"))
	_pt(Vector3(-hx + 1.6, 0, -hz + 1.9), 1.9, "bench", "Осмотреть верстак")
	_pt(Vector3(-1.5, 0, -hz + 1.4), 1.5, "chest", "Открыть ящик")
	npc_spots = [Vector3(0, 0, -0.5)]


func _makar() -> void:
	_window(Vector3(-hx + 0.02, 1.7, -0.5), PI / 2)
	_window(Vector3(2.5, 1.7, -hz + 0.02), 0.0)
	_bed(Vector3(hx - 1.1, 0, -hz + 1.6), 0.0, Color("3a5a8a"), 1.3)
	_stove(Vector3(-hx + 1.3, 0, -hz + 0.7))
	_table(Vector3(-0.8, 0, 0.8), 1.7, 0.95)
	_chair(Vector3(-1.7, 0, 0.8), -PI / 2)
	_chair(Vector3(0.1, 0, 0.8), PI / 2)
	_shelf(Vector3(0.4, 0, -hz + 0.35), 0.0, 1.8, 4)
	_chest(Vector3(hx - 0.7, 0, 1.0), -PI / 2)
	_rug(Vector3(-0.8, 0, 0.9), 3.0, 2.2, Color("2a4a2a"), Color("a8905a"))
	_frame(Vector3(hx - 0.05, 2.0, 0.4), -PI / 2, Color("b0a080"))
	_frame(Vector3(-1.2, 2.0, -hz + 0.05), 0.0, Color("8a6a5a"))
	# письмо на столе
	var letter := MeshKit.glow_inst([MeshKit.box(Vector3(0.35, 0.02, 0.25), Vector3(0, 0, 0), Color("fff6d0"))], Color("fff0b0"), self, 1.2)
	letter.position = Vector3(-0.7, 0.89, 0.8)
	_pt(Vector3(-0.8, 0, 1.0), 1.8, "letter", "Осмотреть стол")
	_pt(Vector3(hx - 1.0, 0, 1.0), 1.5, "chest", "Открыть сундук")
	_pt(Vector3(hx - 1.6, 0, -hz + 2.4), 1.7, "bed", "Отдохнуть")
	npc_spots = [Vector3(1.0, 0, 0.8), Vector3(-1.6, 0, 1.8)]


func _lyuda() -> void:
	_window(Vector3(hx - 0.02, 1.7, -0.8), -PI / 2)
	_window(Vector3(-2.5, 1.7, -hz + 0.02), 0.0)
	_bed(Vector3(-hx + 1.2, 0, -hz + 1.6), 0.0, Color("c06a9a"), 1.4)
	_stove(Vector3(hx - 1.5, 0, -hz + 0.7))
	_table(Vector3(0.2, 0, 0.6), 1.9, 1.1, Color("b08a5a"))
	_chair(Vector3(-0.8, 0, 0.6), -PI / 2, Color("a05a7a"))
	_chair(Vector3(1.2, 0, 0.6), PI / 2, Color("a05a7a"))
	_chair(Vector3(0.2, 0, 1.6), PI, Color("a05a7a"))
	_shelf(Vector3(-0.6, 0, -hz + 0.35), 0.0, 2.2, 4)
	# тарелка с пирожками
	MeshKit.inst([MeshKit.cyl(0.28, 0.24, 0.04, Vector3(0, 0.89, 0), Color("f2f2f2"), Vector3.ZERO, 12),
		MeshKit.sph(0.1, Vector3(-0.1, 0.97, 0), Color("d8a05a"), Vector3(1.3, 0.8, 1), 7),
		MeshKit.sph(0.1, Vector3(0.1, 0.97, 0.05), Color("d8a05a"), Vector3(1.3, 0.8, 1), 7)], self, Vector3(0.2, 0, 0.6))
	_rug(Vector3(0.2, 0, 0.8), 3.6, 2.6, Color("9a3a6a"), Color("e8c6a0"))
	_cat(Vector3(-hx + 1.0, 0.0, 1.4), Color("c98a4a"))
	_chest(Vector3(hx - 0.6, 0, 1.4), -PI / 2)
	_lamp_floor(Vector3(hx - 0.8, 0, hz - 0.8))
	_frame(Vector3(-hx + 0.05, 2.0, 0.8), PI / 2, Color("d8a0b8"))
	_pt(Vector3(0.2, 0, 1.0), 1.8, "pie", "Съесть пирожок")
	_pt(Vector3(hx - 1.1, 0, 1.4), 1.4, "chest", "Открыть сундук")
	_pt(Vector3(-hx + 1.0, 0, 1.4), 1.3, "cat", "Погладить кота")
	npc_spots = [Vector3(-1.5, 0, 1.8), Vector3(2.0, 0, 1.8), Vector3(0.8, 0, 2.2)]


func _bytovka() -> void:
	_window(Vector3(hx - 0.02, 1.7, -0.6), -PI / 2)
	# двухъярусные нары
	_bed(Vector3(-hx + 1.0, 0, -hz + 1.5), 0.0, Color("4a6a3a"), 1.1)
	MeshKit.inst([MeshKit.box(Vector3(1.0, 0.1, 2.0), Vector3(0, 1.55, 0), Color("6a4326")),
		MeshKit.box(Vector3(0.9, 0.12, 1.9), Vector3(0, 1.66, 0), Color("c9a05a")),
		MeshKit.box(Vector3(0.08, 1.5, 0.08), Vector3(-0.5, 0.75, 0.95), Color("5a3a20")),
		MeshKit.box(Vector3(0.08, 1.5, 0.08), Vector3(0.5, 0.75, 0.95), Color("5a3a20"))], self, Vector3(-hx + 1.0, 0.1, -hz + 1.5))
	_table(Vector3(1.0, 0, 0.4), 1.5, 0.9, Color("7a6a50"))
	_chair(Vector3(0.1, 0, 0.4), -PI / 2, Color("6a5a40"))
	_chair(Vector3(1.9, 0, 0.4), PI / 2, Color("6a5a40"))
	# трубы и сантехника — гордость Коли
	var pipes: Array = []
	for i in 4:
		pipes.append(MeshKit.cyl(0.07, 0.07, hx * 1.4, Vector3(0, 2.4 - i * 0.12, 0), Color("b0b6be"), Vector3(0, 0, PI / 2), 8))
	pipes.append(MeshKit.cyl(0.07, 0.07, 2.4, Vector3(-1.5, 1.2, 0), Color("b0b6be"), Vector3.ZERO, 8))
	pipes.append(MeshKit.cyl(0.07, 0.07, 2.4, Vector3(1.5, 1.2, 0), Color("b0b6be"), Vector3.ZERO, 8))
	MeshKit.inst(pipes, self, Vector3(0.6, 0, -hz + 0.25))
	# ключ и ведро
	MeshKit.inst([MeshKit.box(Vector3(0.1, 0.9, 0.04), Vector3(0, 0.45, 0), Color("c9532a")),
		MeshKit.cyl(0.25, 0.2, 0.4, Vector3(0.7, 0.2, 0.2), Color("5a7a9a"), Vector3.ZERO, 10)], self, Vector3(hx - 1.5, 0, -hz + 0.6))
	_stove(Vector3(hx - 1.3, 0, -hz + 2.2), -PI / 2)
	_chest(Vector3(-hx + 0.6, 0, 1.2), PI / 2)
	_rug(Vector3(1.0, 0, 0.5), 2.6, 2.0, Color("3a4a5a"), Color("7a8a9a"))
	_pt(Vector3(-hx + 1.0, 0, 1.0), 1.6, "chest", "Открыть ящик")
	_pt(Vector3(1.0, 0, 0.9), 1.6, "tv", "Включить телек")
	npc_spots = [Vector3(0.6, 0, 1.8), Vector3(-1.6, 0, 1.0)]


func _shop() -> void:
	_window(Vector3(hx - 0.02, 1.8, 0.4), -PI / 2)
	_window(Vector3(-hx + 0.02, 1.8, 0.4), PI / 2)
	# прилавок
	var cp: Array = [MeshKit.box(Vector3(5.0, 1.05, 0.9), Vector3(0, 0.52, 0), Color("a0763e")),
		MeshKit.box(Vector3(5.2, 0.08, 1.05), Vector3(0, 1.08, 0), Color("d8c09a")),
		MeshKit.box(Vector3(0.7, 0.35, 0.5), Vector3(1.6, 1.28, 0), Color("c8c8c8")),
		MeshKit.box(Vector3(0.5, 0.4, 0.35), Vector3(-1.4, 1.32, 0), Color("2a2a2a"))]
	MeshKit.inst(cp, self, Vector3(0, 0, -1.0))
	MeshKit.static_box(self, Vector3(5.2, 1.1, 1.0), Vector3(0, 0.55, -1.0))
	_shelf(Vector3(-3.4, 0, -hz + 0.35), 0.0, 3.0, 4, true)
	_shelf(Vector3(1.0, 0, -hz + 0.35), 0.0, 3.0, 4, true)
	_shelf(Vector3(hx - 0.35, 0, 1.0), -PI / 2, 3.4, 3, true)
	_shelf(Vector3(-hx + 0.35, 0, 1.4), PI / 2, 2.6, 3, true)
	# холодильник с мороженым
	MeshKit.inst([MeshKit.box(Vector3(1.4, 1.0, 0.8), Vector3(0, 0.5, 0), Color("e8eef2")),
		MeshKit.box(Vector3(1.3, 0.05, 0.7), Vector3(0, 1.02, 0), Color("9ad0e8"))], self, Vector3(-hx + 1.4, 0, hz - 1.3))
	MeshKit.static_box(self, Vector3(1.4, 1.0, 0.8), Vector3(-hx + 1.4, 0.5, hz - 1.3))
	# мешки картошки
	MeshKit.inst([MeshKit.box(Vector3(0.6, 0.5, 0.4), Vector3(0, 0.25, 0), Color("c9a86a")),
		MeshKit.box(Vector3(0.6, 0.5, 0.4), Vector3(0.7, 0.25, 0.1), Color("b8955a")),
		MeshKit.box(Vector3(0.55, 0.45, 0.4), Vector3(0.35, 0.72, 0.05), Color("c9a86a"))], self, Vector3(hx - 1.3, 0, hz - 1.0))
	var sign := MeshKit.label("ПРОДУКТЫ", Vector3(0, 2.6, -hz + 0.06), Color("ffd23a"), 60, 0.01, false, self)
	sign.shaded = false
	_rug(Vector3(0, 0, 1.4), 4.0, 2.0, Color("3a5a8a"), Color("a8b8c8"))
	_pt(Vector3(0, 0, 0.1), 2.2, "buy", "Купить еду")
	npc_spots = [Vector3(0, 0, -2.0)]


func _process(delta: float) -> void:
	t += delta
	if cat != null:
		cat.rotation.y = sin(t * 0.7) * 0.25
		cat.scale.y = 1.0 + sin(t * 2.2) * 0.04

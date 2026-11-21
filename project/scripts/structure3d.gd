class_name Structure3D
extends StaticBody3D
## Постройка игрока: стена, забор, костёр, шипы. Волки ломают их, костёр их пугает.

signal destroyed(s: Structure3D)

const CAT := {
	"wall": {"name": "Стена", "wood": 4, "stone": 0, "hp": 170.0, "size": Vector3(2.0, 2.2, 0.5)},
	"fence": {"name": "Забор", "wood": 2, "stone": 0, "hp": 70.0, "size": Vector3(2.0, 1.1, 0.35)},
	"fire": {"name": "Костёр", "wood": 3, "stone": 1, "hp": 90.0, "size": Vector3(1.3, 0.8, 1.3)},
	"spikes": {"name": "Шипы", "wood": 2, "stone": 1, "hp": 60.0, "size": Vector3(1.8, 0.7, 1.8)},
}
const ORDER := ["wall", "fence", "fire", "spikes"]

var kind := ""
var hp := 100.0
var max_hp := 100.0
var rot_idx := 0
var t := 0.0
var flame: Node3D
var light: OmniLight3D
var dmg_flash := 0.0
var visual: Node3D


static func make_visual(k: String) -> Node3D:
	var n := Node3D.new()
	var parts: Array = []
	match k:
		"wall":
			for i in 5:
				var c := Color("8a5a2b").lightened(0.06 * (i % 2))
				parts.append(MeshKit.cyl(0.21, 0.21, 2.0, Vector3(0, 0.22 + i * 0.44, 0), c, Vector3(0, 0, PI / 2), 8))
				parts.append(MeshKit.cyl(0.17, 0.17, 0.02, Vector3(-1.0, 0.22 + i * 0.44, 0), Color("c98f4f"), Vector3(0, 0, PI / 2), 8))
				parts.append(MeshKit.cyl(0.17, 0.17, 0.02, Vector3(1.0, 0.22 + i * 0.44, 0), Color("c98f4f"), Vector3(0, 0, PI / 2), 8))
			parts.append(MeshKit.box(Vector3(0.16, 2.3, 0.16), Vector3(-0.98, 1.15, 0.2), Color("5b3a22")))
			parts.append(MeshKit.box(Vector3(0.16, 2.3, 0.16), Vector3(0.98, 1.15, 0.2), Color("5b3a22")))
		"fence":
			for x in [-0.9, 0.0, 0.9]:
				parts.append(MeshKit.box(Vector3(0.14, 1.1, 0.14), Vector3(x, 0.55, 0), Color("6b4a2a")))
				parts.append(MeshKit.cyl(0.0, 0.1, 0.18, Vector3(x, 1.18, 0), Color("6b4a2a"), Vector3.ZERO, 4))
			parts.append(MeshKit.box(Vector3(2.0, 0.12, 0.08), Vector3(0, 0.35, 0.1), Color("a8814a")))
			parts.append(MeshKit.box(Vector3(2.0, 0.12, 0.08), Vector3(0, 0.78, 0.1), Color("a8814a")))
		"fire":
			for i in 9:
				var a := i * TAU / 9.0
				parts.append(MeshKit.sph(0.17, Vector3(cos(a) * 0.55, 0.12, sin(a) * 0.55), Color("7d838c"), Vector3(1, 0.8, 1), 6))
			parts.append(MeshKit.cyl(0.08, 0.08, 1.0, Vector3(0, 0.2, 0), Color("5b3a22"), Vector3(0, 0, 0.5), 6))
			parts.append(MeshKit.cyl(0.08, 0.08, 1.0, Vector3(0, 0.2, 0), Color("6b4a2a"), Vector3(0.5, 1.2, 0), 6))
			parts.append(MeshKit.cyl(0.08, 0.08, 1.0, Vector3(0, 0.2, 0), Color("4b2a12"), Vector3(-0.5, 2.4, 0), 6))
		"spikes":
			parts.append(MeshKit.box(Vector3(1.7, 0.1, 1.7), Vector3(0, 0.05, 0), Color("4b2a12")))
			for i in 7:
				var a2 := i * 0.9
				var r := 0.0 if i == 0 else 0.55
				parts.append(MeshKit.cyl(0.0, 0.1, 0.9, Vector3(cos(a2) * r, 0.5, sin(a2) * r), Color("8a5a2b"),
					Vector3(sin(a2) * 0.25, 0, -cos(a2) * 0.25), 5))
	MeshKit.inst(parts, n)
	n.name = "Visual"
	return n


func setup(k: String, ridx: int) -> void:
	kind = k
	rot_idx = ridx
	rotation.y = ridx * PI / 2.0
	var info: Dictionary = CAT[k]
	max_hp = info["hp"]
	hp = max_hp
	visual = make_visual(k)
	add_child(visual)
	var size: Vector3 = info["size"]
	if k != "spikes":
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position.y = size.y / 2.0
		add_child(cs)
	if k == "fire":
		flame = Node3D.new()
		add_child(flame)
		var fp: Array = [
			MeshKit.cyl(0.0, 0.32, 0.9, Vector3(0, 0.75, 0), Color.WHITE, Vector3.ZERO, 6),
			MeshKit.cyl(0.0, 0.2, 0.6, Vector3(0.1, 0.65, 0.08), Color.WHITE, Vector3.ZERO, 5)]
		MeshKit.glow_inst(fp, Color("ff8a1e"), flame, 3.0)
		MeshKit.glow_inst([MeshKit.cyl(0.0, 0.16, 0.5, Vector3(0, 0.6, 0), Color.WHITE, Vector3.ZERO, 5)], Color("ffe27a"), flame, 4.0)
		light = OmniLight3D.new()
		light.position = Vector3(0, 1.4, 0)
		light.light_color = Color("ffa24a")
		light.omni_range = 13.0
		light.light_energy = 2.4
		add_child(light)
	if k == "spikes":
		add_to_group("spikes")
	if k == "fire":
		add_to_group("fires")
	add_to_group("structures")


func take_damage(n: float) -> void:
	hp -= n
	dmg_flash = 0.25
	if hp <= 0.0:
		destroyed.emit(self)
		queue_free()


func _process(delta: float) -> void:
	t += delta
	if flame != null:
		flame.scale = Vector3(1.0 + sin(t * 17.0) * 0.08, 1.0 + sin(t * 11.0 + 1.0) * 0.18, 1.0 + sin(t * 13.0) * 0.08)
		light.light_energy = 2.2 + sin(t * 9.0) * 0.35 + sin(t * 23.0) * 0.2
	if dmg_flash > 0.0:
		dmg_flash = maxf(0.0, dmg_flash - delta)
		visual.position.x = sin(dmg_flash * 80.0) * dmg_flash * 0.12
	elif visual != null:
		visual.position.x = 0.0

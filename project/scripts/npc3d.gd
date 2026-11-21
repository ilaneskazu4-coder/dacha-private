class_name Npc3D
extends Node3D
## Персонаж-NPC: имя над головой, восклицательный знак задания, поворот к игроку.

var id := ""
var display_name := ""
var kind := "man"
var hum: Humanoid
var marker := false
var show_tag := false
var face_to: Node3D
var name_lbl: Label3D
var mark_lbl: Label3D
var t := 0.0
var base_yaw := 0.0
static var frozen := false      # тесты: NPC стоят на месте
var route: Array = []           # точки маршрута (мировые координаты)
var route_i := 0
var wait := 0.0
var walk_speed := 1.5
var home := ""                  # id дома, куда уходит на ночь
var perma_home := false         # живёт внутри (продавщица)
var at_home := false
var go_home := false
var home_target := Vector3.ZERO
var arrived_home := false
var cur_speed := 0.0


func setup(nm: String, style: Dictionary, collide: bool = true) -> void:
	display_name = nm
	hum = Humanoid.new()
	hum.setup(style)
	hum.dance = style.get("dance", false)
	add_child(hum)
	if collide:
		MeshKit.static_cyl(self, 0.42, 1.8, Vector3(0, 0.9, 0))
	name_lbl = MeshKit.label(nm, Vector3(0, hum.top_y + 0.45, 0), Color.WHITE, 44, 0.0065, true, self)
	mark_lbl = MeshKit.label("!", Vector3(0, hum.top_y + 1.0, 0), Color("ffd23a"), 90, 0.009, true, self)
	mark_lbl.outline_size = 16
	name_lbl.visible = false
	mark_lbl.visible = false


func _process(delta: float) -> void:
	t += delta
	var player_near := face_to != null and face_to.global_position.distance_to(global_position) < 4.0
	var spd := 0.0
	if not frozen and not at_home and not player_near and (route.size() > 0 or go_home):
		if wait > 0.0:
			wait -= delta
		else:
			var tgt: Vector3 = home_target if go_home else route[route_i]
			var d := tgt - position
			d.y = 0.0
			if d.length() < 0.4:
				if go_home:
					arrived_home = true
				else:
					wait = randf_range(2.0, 6.0)
					route_i = (route_i + 1) % route.size()
			else:
				var dir := d.normalized()
				position += dir * walk_speed * delta
				rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), clampf(8.0 * delta, 0.0, 1.0))
				spd = walk_speed * 2.0
	cur_speed = lerpf(cur_speed, spd, clampf(10.0 * delta, 0.0, 1.0))
	hum.animate(delta, cur_speed)
	name_lbl.visible = show_tag
	mark_lbl.visible = marker
	if marker:
		mark_lbl.position.y = hum.top_y + 0.95 + sin(t * 6.0) * 0.1
	if face_to != null and not hum.dance and (player_near or (route.size() == 0 and not go_home)):
		var d2 := face_to.global_position - global_position
		d2.y = 0.0
		var target := base_yaw
		if d2.length() < 6.0:
			target = atan2(-d2.x, -d2.z)
		rotation.y = lerp_angle(rotation.y, target, clampf(5.0 * delta, 0.0, 1.0))

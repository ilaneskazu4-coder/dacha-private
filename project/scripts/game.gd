extends Node
## Глобальное состояние игры (автозагрузка "Game"): ресурсы, здоровье, день, сохранения.

signal changed

const SAVE_PATH := "user://dacha_save.cfg"
const WOOD_GOAL := 10
const SAVED := ["wood", "stone", "hp", "day", "kills", "stage", "intro_done", "best_day", "structures", "quest", "q_state", "q_base", "fish", "bosses", "cash", "owned_sport", "yacht", "has_pistol", "has_shotgun", "ammo_p", "ammo_s", "m1_done"]

var wood := 4
var stone := 0
var hp := 100.0
var max_hp := 100.0
var day := 1
var kills := 0
## 0-1: собираем брёвна, 2: строим костёр, 3: первая ночь, 4: свободное выживание
var stage := 0
var intro_done := false
var best_day := 1
var structures: Array = []
var quest := 0
var q_state := 0
var q_base := 0
var fish := 0
var bosses := 0
var cash := 0
var owned_sport := false
var yacht := false
var m1_done := false
var has_pistol := false
var has_shotgun := false
var ammo_p := 0
var ammo_s := 0
var no_save := false


func _ready() -> void:
	var ns := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--smoke") or a == "--snapshot" or a == "--shot-menu" or a == "--shot-coop":
			ns = true
	if ns:
		no_save = true
	else:
		load_game()



func add_wood(n: int) -> void:
	wood += n
	changed.emit()


func add_stone(n: int) -> void:
	stone += n
	changed.emit()


func set_stage(s: int) -> void:
	stage = s
	changed.emit()
	save()


func can_afford(w: int, s: int) -> bool:
	return wood >= w and stone >= s


func spend(w: int, s: int) -> void:
	wood -= w
	stone -= s
	changed.emit()


func objective() -> String:
	match stage:
		0, 1:
			return "Нарубай брёвна для лагеря (бей топором по деревьям): %d / %d" % [mini(wood, WOOD_GOAL), WOOD_GOAL]
		2:
			return "Построй костёр до ночи: кнопка «Стройка» → костёр. Волки боятся огня."
		3:
			return "Пережди первую ночь! Держись у костра и бей волков топором."
		_:
			return "День %d. Укрепляй дачу стенами и костром. Убито волков: %d" % [day, kills]


func save() -> void:
	if no_save:
		return
	var c := ConfigFile.new()
	for k in SAVED:
		c.set_value("g", k, get(k))
	c.save(SAVE_PATH)
	Ysdk.cloud_save(to_dict())


func to_dict() -> Dictionary:
	var d := {}
	for k in SAVED:
		d[k] = get(k)
	return d


func score_of(d: Dictionary) -> int:
	return int(d.get("quest", 0)) * 1000 + int(d.get("best_day", 1)) * 10 + int(d.get("kills", 0)) / 10


## Применить сохранение из облака, если оно дальше локального.
func apply_dict(d: Dictionary) -> bool:
	if score_of(d) <= score_of(to_dict()):
		return false
	for k in SAVED:
		if d.has(k):
			var v: Variant = d[k]
			if typeof(get(k)) == TYPE_INT and typeof(v) == TYPE_FLOAT:
				v = int(v)
			set(k, v)
	if hp <= 0.0:
		hp = max_hp
	changed.emit()
	return true


func load_game() -> void:
	var c := ConfigFile.new()
	if c.load(SAVE_PATH) != OK:
		return
	for k in SAVED:
		if c.has_section_key("g", k):
			set(k, c.get_value("g", k))
	if hp <= 0.0:
		hp = max_hp


## Новая партия для игры вместе: отдельный мир, личное сохранение не трогаем.
func coop_reset() -> void:
	no_save = true
	wood = 8
	stone = 0
	hp = max_hp
	day = 1
	kills = 0
	stage = 1
	intro_done = true
	structures = []
	quest = 0
	q_state = 0
	q_base = 0
	fish = 0
	bosses = 0
	cash = 100
	owned_sport = false
	yacht = false
	m1_done = false
	has_pistol = false
	has_shotgun = false
	ammo_p = 0
	ammo_s = 0
	changed.emit()


func reset_all() -> void:
	wood = 4
	stone = 0
	hp = max_hp
	day = 1
	kills = 0
	stage = 0
	intro_done = false
	structures = []
	quest = 0
	q_state = 0
	q_base = 0
	fish = 0
	bosses = 0
	cash = 0
	owned_sport = false
	yacht = false
	m1_done = false
	has_pistol = false
	has_shotgun = false
	ammo_p = 0
	ammo_s = 0
	save()

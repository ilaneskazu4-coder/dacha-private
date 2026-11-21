extends Node
## Настройки игрока (автозагрузка "Settings"): качество, громкость, чувствительность, язык.

signal changed

const PATH := "user://settings.cfg"

var quality := 1          # 0 низкая, 1 обычная, 2 высокая
var music := 0.8
var sfx := 1.0
var sens := 1.0
var lang := "auto"        # auto, ru, en
var nick := ""
const DEFAULT_RELAY := ""   # сюда вшивается адрес воркера https://….workers.dev (wss://…)
var relay := DEFAULT_RELAY
var no_save := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--smoke") or a == "--snapshot" or a.begins_with("--net-") or a == "--shot-coop":
			no_save = true
	quality = 2 if not (OS.has_feature("web") or OS.has_feature("mobile")) else 1
	_load()
	if nick == "":
		nick = "Дачник%d" % (10 + randi() % 90)
	apply_audio()


func _load() -> void:
	if no_save:
		return
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	quality = clampi(int(c.get_value("s", "quality", quality)), 0, 2)
	music = clampf(float(c.get_value("s", "music", music)), 0.0, 1.0)
	sfx = clampf(float(c.get_value("s", "sfx", sfx)), 0.0, 1.0)
	sens = clampf(float(c.get_value("s", "sens", sens)), 0.4, 2.0)
	lang = str(c.get_value("s", "lang", lang))
	nick = str(c.get_value("s", "nick", nick)).substr(0, 14)
	relay = str(c.get_value("s", "relay", relay))


func save() -> void:
	if no_save:
		return
	var c := ConfigFile.new()
	c.set_value("s", "quality", quality)
	c.set_value("s", "music", music)
	c.set_value("s", "sfx", sfx)
	c.set_value("s", "sens", sens)
	c.set_value("s", "lang", lang)
	c.set_value("s", "nick", nick)
	c.set_value("s", "relay", relay)
	c.save(PATH)


func apply_audio() -> void:
	_bus("Music", music)
	_bus("SFX", sfx)


func _bus(nm: String, v: float) -> void:
	var i := AudioServer.get_bus_index(nm)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(i, v <= 0.001)


## Язык интерфейса: ключи запуска главнее настроек, потом язык платформы.
func resolve_lang() -> String:
	var args := OS.get_cmdline_user_args()
	if "--en" in args:
		return "en"
	if "--ru" in args:
		return "ru"
	if lang == "ru" or lang == "en":
		return lang
	return Ysdk.lang() if Ysdk.is_web else OS.get_locale_language()


func base_scale() -> float:
	return 0.7 if quality == 0 else 1.0


func notify() -> void:
	apply_audio()
	save()
	changed.emit()

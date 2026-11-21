extends Node
## Обёртка над Yandex Games SDK (автозагрузка "Ysdk").
## В браузере на Яндекс Играх работает через window.ysdk, вне площадки имитирует рекламу (2 секунды),
## чтобы игру можно было проверять и на ПК, и в APK.

signal ad_result(ok: bool)
signal cloud_loaded(data: Dictionary)

var is_web := false
var sdk_ok := false
var ad_pending := false
var sim_t := 0.0
var shown_ads := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	is_web = OS.has_feature("web")
	_check()
	if is_web:
		JavaScriptBridge.eval("window.__paused = false; document.addEventListener('visibilitychange', function(){ window.__paused = document.hidden; }); window.addEventListener('blur', function(){ window.__paused = true; }); window.addEventListener('focus', function(){ window.__paused = document.hidden; });", true)


func _check() -> void:
	if is_web and not sdk_ok:
		sdk_ok = _js_bool("typeof window.ysdk !== 'undefined' && window.ysdk !== null")


func _js_bool(code: String) -> bool:
	var r: Variant = JavaScriptBridge.eval(code, true)
	# в веб-сборке Godot булевы значения из JS приходят числом 1, а не true
	return r != null and (r is bool or r is int or r is float) and int(r) == 1


func game_ready() -> void:
	if _ready_sent:
		return
	_ready_sent = true
	_check()
	if is_web and sdk_ok:
		JavaScriptBridge.eval("try { window.ysdk.features.LoadingAPI.ready(); } catch(e) {}", true)
		JavaScriptBridge.eval("try { window.ysdk.on('game_api_pause', function(){ window.__paused = true; }); window.ysdk.on('game_api_resume', function(){ window.__paused = document.hidden; }); } catch(e) {}", true)


## Закреплённый баннер Яндекса (показывает сама платформа).
func show_banner() -> void:
	if _banner_sent:
		return
	_banner_sent = true
	_check()
	if is_web and sdk_ok:
		JavaScriptBridge.eval("try { window.ysdk.adv.showBannerAdv(); } catch(e) {}", true)


func gameplay(on: bool) -> void:
	if is_web and sdk_ok:
		var fn := "start" if on else "stop"
		JavaScriptBridge.eval("try { window.ysdk.features.GameplayAPI.%s(); } catch(e) {}" % fn, true)


func lang() -> String:
	if is_web and sdk_ok:
		var r: Variant = JavaScriptBridge.eval("(window.ysdk.environment && window.ysdk.environment.i18n && window.ysdk.environment.i18n.lang) || 'ru'", true)
		return str(r)
	return "ru"


## Реклама за награду (возрождение и т. п.). Результат приходит в сигнал ad_result.
func show_rewarded() -> void:
	_check()
	if ad_pending:
		return
	ad_pending = true
	shown_ads += 1
	AudioServer.set_bus_mute(0, true)
	if is_web and sdk_ok:
		JavaScriptBridge.eval("window.__ad = {done:false, ok:false}; try { window.ysdk.adv.showRewardedVideo({callbacks:{onRewarded:function(){window.__ad.ok=true;}, onClose:function(){window.__ad.done=true;}, onError:function(e){window.__ad.done=true;}}}); } catch(e) { window.__ad.done = true; }", true)
	else:
		sim_t = 2.0


## Полноэкранная реклама в естественной паузе (например, на рассвете).
func show_interstitial() -> void:
	if is_web and sdk_ok:
		JavaScriptBridge.eval("try { window.ysdk.adv.showFullscreenAdv({callbacks:{}}); } catch(e) {}", true)


var host_paused := false
var user_paused := false
var _ready_sent := false
var _banner_sent := false


## Единое место, где решается, стоит ли игра: пауза платформы, реклама или пауза игрока.
func apply_pause() -> void:
	get_tree().paused = host_paused or ad_pending or (user_paused and not Net.active)
	AudioServer.set_bus_mute(0, host_paused or ad_pending)


func _process(delta: float) -> void:
	if is_web:
		_poll_cloud()
		var hp := _js_bool("window.__paused === true")
		if hp != host_paused:
			host_paused = hp
			apply_pause()
	if not ad_pending:
		return
	if is_web and sdk_ok:
		if _js_bool("window.__ad && window.__ad.done === true"):
			_finish(_js_bool("window.__ad.ok === true"))
	else:
		sim_t -= delta
		if sim_t <= 0.0:
			_finish(true)


func _finish(ok: bool) -> void:
	ad_pending = false
	AudioServer.set_bus_mute(0, host_paused)
	ad_result.emit(ok)


# ---------- облачные сохранения Яндекса ----------

var cloud_wait := false
var cloud_last := -100.0


func cloud_load() -> void:
	_check()
	if not (is_web and sdk_ok):
		return
	cloud_wait = true
	JavaScriptBridge.eval("window.__cloud = {done:false, data:''}; window.ysdk.getPlayer().then(function(p){ window.__player = p; return p.getData(['save']); }).then(function(d){ window.__cloud.data = (d && d.save) ? JSON.stringify(d.save) : ''; window.__cloud.done = true; }).catch(function(){ window.__cloud.done = true; });", true)


func cloud_save(d: Dictionary) -> void:
	if not (is_web and sdk_ok):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - cloud_last < 8.0:
		return
	cloud_last = now
	var js := JSON.stringify(d)
	JavaScriptBridge.eval("try { if (window.__player) window.__player.setData({save: %s}, false); } catch(e) {}" % js, true)


func _poll_cloud() -> void:
	if cloud_wait and _js_bool("window.__cloud && window.__cloud.done === true"):
		cloud_wait = false
		var txt := str(JavaScriptBridge.eval("window.__cloud.data", true))
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary:
			cloud_loaded.emit(parsed)

extends Node
## Сеть для игры вместе (автозагрузка "Net"). Один игрок создаёт комнату, остальные заходят.
## Серверов не нужно: по одной Wi-Fi или раздаче с телефона друзья находят комнату сами,
## через интернет можно зайти по адресу (например, через бесплатный ZeroTier или Tailscale).
## Мир общий (время, деревья, постройки, волки), прогресс по сюжету у каждого свой.

signal lobby_changed
signal join_failed(msg: String)
signal game_begin
signal left(msg: String)

const PORT := 47777
const DISC := 47778
const MAX_PLAYERS := 4
const COLORS := [Color("b3261e"), Color("2f7ad0"), Color("2f9d4a"), Color("d08a1e")]
const STATE_HZ := 15.0
const SNAP_HZ := 10.0

var active := false
var in_lobby := false
var is_host := false
var started := false
var my_name := "Дачник"
var players := {}        # id -> {"name": String, "idx": int}
var rooms := {}          # ip -> {"name": String, "n": int, "t": float}
var remotes := {}        # id -> RemotePlayer
var main: Node = null
var peer: MultiplayerPeer
var online := false
var room_code := ""
var udp_tx: PacketPeerUDP
var udp_rx: PacketPeerUDP
var pvp := false
var searching := false
var bc_t := 0.0
var st_t := 0.0
var snap_t := 0.0
var time_t := 0.0
var next_wolf := 1
var wolf_seen := {}      # id -> время последнего снимка (на клиенте)
var wolf_nodes := {}     # id -> Wolf3D (на клиенте)
var clock := 0.0
var swing_flag_t := 0.0


func _ready() -> void:
	randomize()
	my_name = Settings.nick
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.connection_failed.connect(_on_connect_fail)
	multiplayer.server_disconnected.connect(_on_server_gone)
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--net-host":
			_auto_host.call_deferred()
		elif a.begins_with("--net-join="):
			_auto_join.call_deferred(a.substr(11))
		elif a.begins_with("--net-relay="):
			Settings.relay = a.substr(12)
		elif a == "--net-ohost":
			_auto_ohost.call_deferred()
		elif a.begins_with("--net-ojoin="):
			_auto_ojoin.call_deferred(a.substr(12))
		elif a.begins_with("--net-name="):
			my_name = a.substr(11)


func _auto_host() -> void:
	host_room()
	var want := 2
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net-wait="):
			want = int(a.substr(11))
	while players.size() < want:
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(1.0).timeout
	begin_game()


func _auto_ohost() -> void:
	await get_tree().create_timer(0.5).timeout
	host_online("TEST1")
	while players.size() < 2:
		await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(1.0).timeout
	begin_game()


func _auto_ojoin(code: String) -> void:
	await get_tree().create_timer(1.5).timeout
	join_online(code)


func _auto_join(ip: String) -> void:
	await get_tree().create_timer(1.5).timeout
	join(ip)


# ---------------- адреса ----------------

static func local_ips() -> Array:
	var res: Array = []
	for a in IP.get_local_addresses():
		var s := String(a)
		if s.count(".") != 3 or s.begins_with("127.") or s.begins_with("169.254."):
			continue
		res.append(s)
	return res


func my_address() -> String:
	var l := local_ips()
	return String(l[0]) if not l.is_empty() else "—"


# ---------------- комната ----------------

func _reset_state() -> void:
	players.clear()
	rooms.clear()
	remotes.clear()
	wolf_nodes.clear()
	wolf_seen.clear()
	started = false
	active = false
	in_lobby = false
	main = null


func host_room() -> bool:
	leave(false)
	var ep := ENetMultiplayerPeer.new()
	var err: int = ep.create_server(PORT, MAX_PLAYERS - 1)
	peer = ep
	if err != OK:
		join_failed.emit("Не удалось создать комнату (порт занят?)")
		peer = null
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	in_lobby = true
	players = {1: {"name": my_name, "idx": 0}}
	_start_broadcast()
	lobby_changed.emit()
	return true


func join(ip: String) -> void:
	leave(false)
	ip = ip.strip_edges()
	if ip == "":
		join_failed.emit("Введи адрес комнаты")
		return
	var ep := ENetMultiplayerPeer.new()
	var err: int = ep.create_client(ip, PORT)
	peer = ep
	if err != OK:
		join_failed.emit("Не удалось подключиться")
		peer = null
		return
	multiplayer.multiplayer_peer = peer
	is_host = false
	in_lobby = true


static func new_code() -> String:
	var ab := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var c := ""
	for i in 5:
		c += ab[randi() % ab.length()]
	return c


func _relay_url() -> String:
	var u := Settings.relay.strip_edges()
	if u.begins_with("https://"):
		u = "wss://" + u.substr(8)
	elif u.begins_with("http://"):
		u = "ws://" + u.substr(7)
	elif u != "" and not u.begins_with("ws"):
		u = "wss://" + u
	return u


func host_online(code := "") -> bool:
	leave(false)
	var url := _relay_url()
	if url == "":
		join_failed.emit("Не задан адрес сервера. Меню → Свой сервер")
		return false
	if code == "":
		code = new_code()
	var rp := RelayPeer.new()
	if rp.open(url, code, true) != OK:
		join_failed.emit("Не удалось связаться с сервером")
		return false
	rp.failed.connect(_on_relay_fail)
	peer = rp
	multiplayer.multiplayer_peer = peer
	online = true
	room_code = code.to_upper()
	is_host = true
	in_lobby = true
	players = {1: {"name": my_name, "idx": 0}}
	lobby_changed.emit()
	return true


func join_online(code: String) -> void:
	leave(false)
	code = code.strip_edges().to_upper()
	var url := _relay_url()
	if url == "":
		join_failed.emit("Не задан адрес сервера. Меню → Свой сервер")
		return
	if code.length() < 4:
		join_failed.emit("Введи код комнаты")
		return
	var rp := RelayPeer.new()
	if rp.open(url, code, false) != OK:
		join_failed.emit("Не удалось связаться с сервером")
		return
	rp.failed.connect(_on_relay_fail)
	peer = rp
	multiplayer.multiplayer_peer = peer
	online = true
	room_code = code
	is_host = false
	in_lobby = true


func _on_relay_fail(code: int) -> void:
	var msg := "Нет связи с сервером"
	match code:
		1: msg = "Комнаты с таким кодом нет"
		2: msg = "Этот код уже занят, попробуй ещё раз"
		3: msg = "В комнате нет мест"
		4: msg = "Хозяин комнаты вышел"
	if code == 4 and (active or in_lobby):
		_on_server_gone()
		return
	leave(false)
	join_failed.emit(msg)


func leave(notify := true) -> void:
	stop_search()
	if udp_tx != null:
		udp_tx.close()
		udp_tx = null
	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	online = false
	room_code = ""
	var was := active or in_lobby
	_reset_state()
	is_host = false
	if notify and was:
		left.emit("")


func begin_game() -> void:
	if not is_host or started:
		return
	started = true
	_stop_broadcast()
	_go.rpc()


@rpc("authority", "call_local", "reliable")
func _go() -> void:
	started = true
	active = true
	in_lobby = false
	stop_search()
	Game.coop_reset()
	game_begin.emit()
	get_tree().change_scene_to_file("res://main.tscn")


func _on_peer_connected(id: int) -> void:
	if is_host and started and peer != null:
		peer.disconnect_peer(id)


func _on_peer_disconnected(id: int) -> void:
	if players.has(id):
		var nm: String = players[id]["name"]
		players.erase(id)
		if is_host:
			_players.rpc(players)
		if remotes.has(id):
			(remotes[id] as Node).queue_free()
			remotes.erase(id)
		if main != null and main.has_method("net_toast"):
			main.net_toast("%s вышел из игры" % nm)
		lobby_changed.emit()


func _on_connected_ok() -> void:
	_register.rpc_id(1, my_name)


func _on_connect_fail() -> void:
	leave(false)
	join_failed.emit("Комната не найдена. Проверь адрес и Wi-Fi")


func _on_server_gone() -> void:
	var was_active := active
	leave(false)
	left.emit("Хозяин комнаты вышел")
	if was_active:
		get_tree().change_scene_to_file("res://menu.tscn")


@rpc("any_peer", "reliable")
func _register(nm: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if started or players.size() >= MAX_PLAYERS:
		peer.disconnect_peer(id)
		return
	var used := []
	for k in players:
		used.append(int(players[k]["idx"]))
	var idx := 0
	while idx in used:
		idx += 1
	players[id] = {"name": nm.substr(0, 14), "idx": idx}
	_players.rpc(players)
	lobby_changed.emit()


@rpc("authority", "reliable")
func _players(d: Dictionary) -> void:
	players = d
	lobby_changed.emit()


# ---------------- поиск комнат по Wi-Fi ----------------

func _start_broadcast() -> void:
	udp_tx = PacketPeerUDP.new()
	udp_tx.set_broadcast_enabled(true)
	bc_t = 0.0


func _stop_broadcast() -> void:
	if udp_tx != null:
		udp_tx.close()
		udp_tx = null


func start_search() -> void:
	stop_search()
	rooms.clear()
	udp_rx = PacketPeerUDP.new()
	udp_rx.set_broadcast_enabled(true)
	if udp_rx.bind(DISC) == OK:
		searching = true
	else:
		udp_rx = null


func stop_search() -> void:
	searching = false
	if udp_rx != null:
		udp_rx.close()
		udp_rx = null


func _broadcast() -> void:
	var msg := ("DACHA1|%s|%d" % [my_name, players.size()]).to_utf8_buffer()
	var dests := ["255.255.255.255", "127.0.0.1"]
	for ip in local_ips():
		var parts: PackedStringArray = String(ip).split(".")
		parts[3] = "255"
		dests.append(".".join(parts))
	for d in dests:
		udp_tx.set_dest_address(d, DISC)
		udp_tx.put_packet(msg)


func _poll_search() -> void:
	while udp_rx.get_available_packet_count() > 0:
		var pkt := udp_rx.get_packet()
		var ip := udp_rx.get_packet_ip()
		var txt := pkt.get_string_from_utf8()
		var p := txt.split("|")
		if p.size() >= 3 and p[0] == "DACHA1":
			rooms[ip] = {"name": p[1], "n": int(p[2]), "t": clock}
	for ip in rooms.keys():
		if clock - float(rooms[ip]["t"]) > 4.0:
			rooms.erase(ip)


# ---------------- игра ----------------

func attach(m: Node) -> void:
	main = m
	var my := multiplayer.get_unique_id()
	for id in players:
		if id == my:
			continue
		var rp := RemotePlayer.new()
		m.add_child(rp)
		rp.setup(id, players[id]["name"], int(players[id]["idx"]))
		remotes[id] = rp
	# своя цветовая рубашка не нужна: у хозяина остаётся классический Михалыч


func detach() -> void:
	main = null
	remotes.clear()
	wolf_nodes.clear()
	wolf_seen.clear()


func my_idx() -> int:
	var id := multiplayer.get_unique_id()
	return int(players[id]["idx"]) if players.has(id) else 0


func _process(delta: float) -> void:
	clock += delta
	if udp_tx != null and is_host and in_lobby and not started:
		bc_t -= delta
		if bc_t <= 0.0:
			bc_t = 1.0
			_broadcast()
	if searching and udp_rx != null:
		_poll_search()
	if active and main != null and is_instance_valid(main):
		_tick(delta)


func _tick(delta: float) -> void:
	st_t -= delta
	if st_t <= 0.0:
		st_t = 1.0 / STATE_HZ
		var st: Array = main.net_state()
		_st.rpc(st[0], st[1], st[2], st[3])
	if is_host:
		snap_t -= delta
		if snap_t <= 0.0:
			snap_t = 1.0 / SNAP_HZ
			_wolf_snap.rpc(main.net_wolf_snapshot())
		time_t -= delta
		if time_t <= 0.0:
			time_t = 1.0
			_time.rpc(main.dn.t, main.dn.day)
	else:
		# волки, которых давно нет в снимках хозяина, исчезают
		for id in wolf_seen.keys():
			if clock - float(wolf_seen[id]) > 0.7:
				var w: Wolf3D = wolf_nodes.get(id)
				if w != null and is_instance_valid(w):
					w.die(false)
				wolf_nodes.erase(id)
				wolf_seen.erase(id)


@rpc("any_peer", "unreliable")
func _st(pos: Vector3, face: float, spd: float, flags: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if remotes.has(id):
		(remotes[id] as RemotePlayer).net_update(pos, face, spd, flags)


@rpc("authority", "unreliable")
func _time(t: float, day: int) -> void:
	if main != null:
		main.net_time(t, day)


@rpc("authority", "unreliable")
func _wolf_snap(a: PackedFloat32Array) -> void:
	if main == null:
		return
	var i := 0
	while i + 6 <= a.size():
		var id := int(a[i])
		var kind := int(a[i + 1])
		var pos := Vector3(a[i + 2], 0.0, a[i + 3])
		var yaw := a[i + 4]
		var w: Wolf3D = wolf_nodes.get(id)
		if w == null or not is_instance_valid(w):
			w = main.net_make_wolf(kind, pos)
			wolf_nodes[id] = w
			w.net_id = id
		w.net_pos = pos
		w.net_yaw = yaw
		wolf_seen[id] = clock
		i += 6


# события: удар по дереву/камню, постройки, удар по волку, укус

func send_hit(idx: int, from: Vector3) -> void:
	if active:
		_ev_hit.rpc(idx, from)


@rpc("any_peer", "reliable")
func _ev_hit(idx: int, from: Vector3) -> void:
	if main != null:
		main.net_hit(idx, from)


func send_build(kind: String, x: float, z: float, r: int) -> void:
	if active:
		_ev_build.rpc(kind, x, z, r)


@rpc("any_peer", "reliable")
func _ev_build(kind: String, x: float, z: float, r: int) -> void:
	if main != null:
		main.net_build(kind, x, z, r)


func send_unbuild(x: float, z: float) -> void:
	if active:
		_ev_unbuild.rpc(x, z)


@rpc("any_peer", "reliable")
func _ev_unbuild(x: float, z: float) -> void:
	if main != null:
		main.net_unbuild(x, z)


func send_wolf_hit(id: int, dmg: float, from: Vector3) -> void:
	if active and not is_host:
		_rq_wolf_hit.rpc_id(1, id, dmg, from)


@rpc("any_peer", "reliable")
func _rq_wolf_hit(id: int, dmg: float, from: Vector3) -> void:
	if is_host and main != null:
		main.net_wolf_hit(id, dmg, from)


func send_bite(peer_id: int, dmg: float, from: Vector3) -> void:
	if active and is_host:
		_take_hit.rpc_id(peer_id, dmg, from)


@rpc("authority", "reliable")
func _take_hit(dmg: float, from: Vector3) -> void:
	if main != null:
		main.net_take_hit(dmg, from)


func send_toast(text: String) -> void:
	if active:
		_toast.rpc(text)


@rpc("any_peer", "reliable")
func _toast(text: String) -> void:
	if main != null:
		main.net_toast(text)


# ---------------- приколы: PvP, бочки, воскрешение, соревнования ----------------

func set_pvp(on: bool) -> void:
	if is_host and (in_lobby or active):
		_pvp_set.rpc(on)


@rpc("authority", "call_local", "reliable")
func _pvp_set(on: bool) -> void:
	pvp = on
	lobby_changed.emit()
	if main != null and main.has_method("net_toast"):
		main.net_toast("PvP: " + ("ВКЛЮЧЁН — друзья бьют друг друга!" if on else "выключен"))


func send_pvp_hit(peer_id: int, dmg: float, from: Vector3, push: float, lift: float, down: float) -> void:
	if active:
		_pvp_hit.rpc_id(peer_id, dmg, from, push, lift, down)


@rpc("any_peer", "reliable")
func _pvp_hit(dmg: float, from: Vector3, push: float, lift: float, down: float) -> void:
	if main != null:
		main.net_pvp_hit(dmg, from, push, lift, down, multiplayer.get_remote_sender_id())


func send_boom(i: int) -> void:
	if active:
		_ev_boom.rpc(i)


@rpc("any_peer", "reliable")
func _ev_boom(i: int) -> void:
	if main != null:
		main.fun.boom(i)


func send_revive(peer_id: int) -> void:
	if active:
		_revive.rpc_id(peer_id)


@rpc("any_peer", "reliable")
func _revive() -> void:
	if main != null:
		main.net_revive(multiplayer.get_remote_sender_id())


func start_activity(kind: String) -> void:
	if is_host and active:
		_act_start.rpc(kind, 90.0)


@rpc("authority", "call_local", "reliable")
func _act_start(kind: String, dur: float) -> void:
	if main != null:
		main.fun.act_start(kind, dur)


func send_score(d: int) -> void:
	if not active:
		return
	if is_host:
		main.fun.add_score(1, d)
	else:
		_act_score.rpc_id(1, d)


@rpc("any_peer", "reliable")
func _act_score(d: int) -> void:
	if is_host and main != null:
		main.fun.add_score(multiplayer.get_remote_sender_id(), d)


func send_act_sync(ids: PackedInt32Array, vals: PackedInt32Array, left: float) -> void:
	if active and is_host:
		_act_sync.rpc(ids, vals, left)


@rpc("authority", "unreliable")
func _act_sync(ids: PackedInt32Array, vals: PackedInt32Array, left: float) -> void:
	if main != null:
		main.fun.act_sync(ids, vals, left)


func send_act_end(msg: String) -> void:
	if active and is_host:
		_act_end.rpc(msg)


@rpc("authority", "call_local", "reliable")
func _act_end(msg: String) -> void:
	if main != null:
		main.fun.act_end(msg)

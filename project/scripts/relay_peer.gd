class_name RelayPeer
extends MultiplayerPeerExtension
## Сетевой «провод» через бесплатного посредника (Cloudflare Worker): комната по короткому коду.
## Протокол: см. relay/relay_core.js. Хозяин всегда id 1, остальные получают номера от посредника.

signal failed(code: int)   # 1 нет такой комнаты, 2 код занят, 3 комната полна, 4 хозяин вышел, 9 нет связи

var ws := WebSocketPeer.new()
var url := ""
var host_mode := false
var my_id := 0
var status := MultiplayerPeer.CONNECTION_CONNECTING
var inbox: Array = []    # [from, mode, PackedByteArray]
var cur_from := 0
var cur_mode := 0
var target := 0
var tmode := 0
var chan := 0
var refuse := false
var clients: Array = []
var opened := false
var dead := false


func open(server: String, code: String, as_host: bool) -> int:
	host_mode = as_host
	var base := server.strip_edges().trim_suffix("/")
	url = "%s/ws/%s?role=%s" % [base, code.strip_edges().to_upper(), "host" if as_host else "join"]
	ws.supported_protocols = PackedStringArray()
	return ws.connect_to_url(url)


func _u32(v: int) -> PackedByteArray:
	var b := PackedByteArray()
	b.resize(4)
	b.encode_u32(0, v)
	# encode_u32 — little-endian; переворачиваем в big-endian
	b.reverse()
	return b


func _rd32(d: PackedByteArray, o: int) -> int:
	return (d[o] << 24) | (d[o + 1] << 16) | (d[o + 2] << 8) | d[o + 3]


func _poll() -> void:
	if dead:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		opened = true
		while ws.get_available_packet_count() > 0:
			_handle(ws.get_packet())
	elif st == WebSocketPeer.STATE_CLOSED:
		dead = true
		var was_conn := status == MultiplayerPeer.CONNECTION_CONNECTED
		status = MultiplayerPeer.CONNECTION_DISCONNECTED
		if not was_conn and my_id == 0:
			failed.emit(9)


func _handle(d: PackedByteArray) -> void:
	if d.size() < 2:
		return
	match d[0]:
		1:
			my_id = _rd32(d, 1)
			status = MultiplayerPeer.CONNECTION_CONNECTED
			if not host_mode:
				peer_connected.emit(1)
		2:
			var id := _rd32(d, 1)
			clients.append(id)
			peer_connected.emit(id)
		3:
			var id := _rd32(d, 1)
			clients.erase(id)
			peer_disconnected.emit(id)
		4:
			if d.size() >= 6:
				inbox.append([_rd32(d, 1), d[5], d.slice(6)])
		5:
			failed.emit(d[1])


func _get_packet_script() -> PackedByteArray:
	if inbox.is_empty():
		return PackedByteArray()
	var p: Array = inbox.pop_front()
	cur_from = p[0]
	cur_mode = p[1]
	return p[2]


func _put_packet_script(buf: PackedByteArray) -> Error:
	if dead or ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ERR_UNAVAILABLE
	var mode := 2 if tmode == MultiplayerPeer.TRANSFER_MODE_RELIABLE else 0
	if host_mode and target < 0:
		for c in clients:
			if c != -target:
				_send_to(c, mode, buf)
		return OK
	var t := target if host_mode and target > 0 else 0
	_send_to(t, mode, buf)
	return OK


func _send_to(t: int, mode: int, buf: PackedByteArray) -> void:
	var m := PackedByteArray([4])
	m.append_array(_u32(t))
	m.append(mode)
	m.append_array(buf)
	ws.send(m, WebSocketPeer.WRITE_MODE_BINARY)


func _get_available_packet_count() -> int:
	return inbox.size()


func _get_max_packet_size() -> int:
	return 1 << 16


func _set_transfer_channel(c: int) -> void:
	chan = c


func _get_transfer_channel() -> int:
	return chan


func _set_transfer_mode(m: MultiplayerPeer.TransferMode) -> void:
	tmode = m


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return tmode as MultiplayerPeer.TransferMode


func _set_target_peer(id: int) -> void:
	target = id


func _get_packet_peer() -> int:
	return cur_from


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return cur_mode as MultiplayerPeer.TransferMode


func _get_packet_channel() -> int:
	return 0


func _is_server() -> bool:
	return host_mode


func _is_server_relay_supported() -> bool:
	return true


func _close() -> void:
	dead = true
	status = MultiplayerPeer.CONNECTION_DISCONNECTED
	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		ws.close()


func _disconnect_peer(id: int, _force: bool) -> void:
	if host_mode and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var m := PackedByteArray([6])
		m.append_array(_u32(id))
		ws.send(m, WebSocketPeer.WRITE_MODE_BINARY)
	elif not host_mode and id == 1:
		_close()


func _get_unique_id() -> int:
	return my_id if my_id > 0 else 0


func _set_refuse_new_connections(b: bool) -> void:
	refuse = b


func _is_refusing_new_connections() -> bool:
	return refuse


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return status as MultiplayerPeer.ConnectionStatus

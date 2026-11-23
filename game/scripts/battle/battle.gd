extends Node
## Battle (autoload): head-to-head score races for up to four players (Evan, 2026-11-23: "a
## multiplayer function so people can battle each other"; he chose a pure score race, player-hosted,
## up to four, songs by vote).
##
## Everyone plays the same song at the same moment and the highest score wins. A battle goes:
##   1. LOBBY: one player hosts, the others join with the lobby code (online) or the host's address
##      (LAN). The host picks the difficulty everyone plays.
##   2. The vote: each player suggests a song from the regions they have open, built-in songs only (a
##      player's own imported songs are on nobody else's computer). The host starts the draw and one
##      suggestion is drawn at random, the same on every screen.
##   3. RACING: the host names a moment on its own clock (`race.zero`, song time 0); each player's
##      song starts then on theirs, through the clock offset measured by pings (_offset_usec). Each
##      player judges their own run and sends SEND_HZ times a second what the others show (score,
##      combo, gas, the keys they hit: rival_bar.gd). Running out of gas freezes your score.
##   4. RESULTS: the standings, once every racer has finished, run out of gas, or left. Every peer
##      gets every finish and sorts the same standings itself.
## Battle runs never touch the save (no bests, no clears), like practice runs.
##
## Transports, as in No Refunds' net.gd:
##   "wasd": a WASD Engine player-hosted lobby (WebRTC; the Web build, or a WASD test run).
##   "lan":  ENet between desktop builds (WASD's desktop lobbies need the webrtc-native extension).
## The host is peer 1 and decides the roster, the suggestions it accepts, the draw and the start.
## Nothing here is cheat-proof: each player scores their own run (a casual race among friends).

signal changed
## The draw is in: `zero_usec` is song time 0 on this computer's Time.get_ticks_usec() clock.
signal race_starting(song_id: String, level: String, suggestions: Array, zero_usec: int)
signal standings_changed
signal closed(reason: String)

enum Phase { NONE, LOBBY, RACING, RESULTS }

const PORT := 24690
const MAX_PLAYERS := 4
const SEND_HZ := 10.0
## The draw's reveal plays this long before the run starts; then the run's lead-in runs to song time 0.
const REVEAL_SECONDS := 3.4
const LEAD_SECONDS := 4.0
const PING_EVERY := 1.0
## The offset comes from the fastest of the latest pings: a slow reply's half-RTT guess is the worst.
const PING_KEEP := 10
const STATE_DRIVING := 0
const STATE_OUT := 1
const STATE_DONE := 2
const STATE_LEFT := 3

var phase: Phase = Phase.NONE
## "", "wasd" or "lan" (see the top).
var transport: String = ""
## The WASD lobby code, or on LAN the host's address for friends to type.
var lobby_code: String = ""
var difficulty: String = "normal"
## peer id -> {"name", "suggestion"}: the host's, copied to every peer.
var roster: Dictionary = {}
## The race on: {"song", "level", "suggestions", "zero" (host usec), "racers" (peer ids)}.
var race: Dictionary = {}
## peer id -> {"name", "score", "combo", "fuel", "hits", "misses", "progress", "hit_lanes",
## "miss_lanes", "state", "at" (local usec of the update)}: every racer's latest, this player's too.
var live: Dictionary = {}
## peer id -> the finished run's numbers (see finish()).
var results: Dictionary = {}
## The name LAN players go by (WASD players use their WASD name).
var my_name: String = "Driver"
## A WASD test run, or main.gd's --battle-auto: suggest and draw without anyone pressing keys.
var auto: bool = false

var _offset_usec: int = 0
var _pings: Array = []
var _ping_left: float = 0.0
var _send_left: float = 0.0
var _hit_mask: int = 0
var _miss_mask: int = 0
var _leaving: bool = false


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_host)
	multiplayer.connection_failed.connect(func() -> void: _close("Couldn't reach the host."))
	multiplayer.server_disconnected.connect(func() -> void: _close("The host closed the battle."))
	# WasdMultiplayer is the autoload before this one, so it is already in the tree. Hook it now: a
	# WASD test run opens its lobby from a call deferred in the add-on's _ready, which runs before
	# anything this script defers (the first test run's host never heard of its own lobby).
	_hook_wasd()
	auto = OS.get_environment("WASD_MULTIPLAYER_TEST") != ""


func _process(delta: float) -> void:
	if phase == Phase.NONE or not _online():
		return
	if not is_host():
		_ping_left -= delta
		if _ping_left <= 0.0:
			_ping_left = PING_EVERY
			_ping.rpc_id(1, Time.get_ticks_usec())


# ---------------------------------------------------------------- connecting

func online_available() -> bool:
	return _wasd() != null and (OS.has_feature("web") or OS.get_environment("WASD_MULTIPLAYER_TEST") != "")


## Browsers can't open UDP sockets; the Web build still has the ENet class, it just can't work.
func lan_available() -> bool:
	return ClassDB.class_exists("ENetMultiplayerPeer") and not OS.has_feature("web")


func is_host() -> bool:
	return multiplayer.is_server()


func me() -> int:
	return multiplayer.get_unique_id()


## Hosts a WASD lobby. Call from a key press or click: a browser opens WASD's sign-in only after one.
func host_online() -> Dictionary:
	if _wasd() == null:
		return {"ok": false, "message": "Online battles aren't set up in this build."}
	var name: String = str(_wasd().player().get("name", "Driver"))
	return await _wasd().host_lobby({"max_players": MAX_PLAYERS, "public": false, "name": "%s's battle" % name})


func join_online(code: String) -> Dictionary:
	if _wasd() == null:
		return {"ok": false, "message": "Online battles aren't set up in this build."}
	return await _wasd().join_lobby(code.strip_edges().to_upper())


## LAN host (desktop). ENet is made by name: naming the class would stop this script loading on the web.
func host_lan(port: int = PORT) -> Error:
	if not lan_available():
		return ERR_UNAVAILABLE
	var peer: MultiplayerPeer = ClassDB.instantiate("ENetMultiplayerPeer")
	var err: Error = peer.call("create_server", port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	transport = "lan"
	var addresses: PackedStringArray = lan_addresses()
	lobby_code = addresses[0] if not addresses.is_empty() else "127.0.0.1"
	_open_lobby({1: {"name": my_name, "suggestion": ""}})
	return OK


func join_lan(address: String, port: int = PORT) -> Error:
	if not lan_available():
		return ERR_UNAVAILABLE
	var peer: MultiplayerPeer = ClassDB.instantiate("ENetMultiplayerPeer")
	var err: Error = peer.call("create_client", address.strip_edges(), port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	transport = "lan"
	lobby_code = address.strip_edges()
	return OK


## Leaves the battle; a host's leaving closes it for everyone.
func leave() -> void:
	_leaving = true
	if transport == "wasd" and _wasd():
		_wasd().leave()
	elif _online():
		multiplayer.multiplayer_peer.close()
	_leaving = false
	_reset()


## This machine's addresses a friend on the same network can join, Wi-Fi and Ethernet first
## (No Refunds' net.gd: virtual adapters and loopback can't be reached from another machine).
func lan_addresses() -> PackedStringArray:
	var ranked: Array = []
	for iface: Dictionary in IP.get_local_interfaces():
		var n: String = str(iface["name"]).to_lower()
		if n.begins_with("lo") or n.begins_with("bridge") or n.begins_with("utun") or n.begins_with("docker") \
				or n.begins_with("veth") or n.begins_with("vmnet") or n.begins_with("vbox") or n.begins_with("virbr"):
			continue
		var rank: int = 0 if (n.begins_with("en") or n.begins_with("wl") or n.begins_with("eth")) else 1
		for a: String in iface["addresses"]:
			var p: PackedStringArray = a.split(".")
			if p.size() == 4 and a.is_valid_ip_address() and (int(p[0]) == 10 or (int(p[0]) == 192 and int(p[1]) == 168) \
					or (int(p[0]) == 172 and int(p[1]) >= 16 and int(p[1]) <= 31)):
				ranked.append([rank, a])
	ranked.sort_custom(func(x: Array, y: Array) -> bool: return int(x[0]) < int(y[0]))
	var out := PackedStringArray()
	for r: Array in ranked:
		if not out.has(str(r[1])):
			out.append(str(r[1]))
	return out


func _wasd() -> Node:
	return get_node_or_null("/root/WasdMultiplayer")


func _online() -> bool:
	return multiplayer.has_multiplayer_peer() and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


func _hook_wasd() -> void:
	var wm: Node = _wasd()
	if wm == null:
		return
	wm.lobby_joined.connect(_on_wasd_lobby)
	wm.lobby_closed.connect(func(reason: String) -> void:
		if _leaving or transport != "wasd":
			return
		var why := {"host_left": "The host closed the battle.", "kicked": "The host removed you from the battle.",
			"dropped": "Couldn't connect to the host in time. Try joining again.",
			"signal_lost": "Lost the connection to WASD Engine."}
		_close(str(why.get(reason, "The battle closed."))))
	# Already in a lobby (hosted or joined before this hooked in): take it up as if it had just opened.
	if not (wm.lobby() as Dictionary).is_empty():
		_on_wasd_lobby.call_deferred(wm.lobby())


## The add-on is in a lobby: hosted here, joined, or opened by a WASD test run on its own. The host
## starts the roster; a joiner introduces itself once Godot says it's connected (_on_connected_to_host).
func _on_wasd_lobby(lobby: Dictionary) -> void:
	transport = "wasd"
	lobby_code = str(lobby.get("code", ""))
	my_name = str(_wasd().player().get("name", my_name)).substr(0, 20)
	if is_host():
		_open_lobby({1: {"name": my_name, "suggestion": ""}})
	elif _online() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_register.rpc_id(1, my_name)


func _on_connected_to_host() -> void:
	phase = Phase.LOBBY
	_register.rpc_id(1, my_name)
	_ping_left = 0.0


func _open_lobby(first: Dictionary) -> void:
	roster = first
	phase = Phase.LOBBY
	changed.emit()


func _close(reason: String) -> void:
	if phase == Phase.NONE and transport.is_empty():
		return
	if _online():
		multiplayer.multiplayer_peer.close()
	_reset()
	closed.emit(reason)


func _reset() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	phase = Phase.NONE
	transport = ""
	lobby_code = ""
	roster.clear()
	race.clear()
	live.clear()
	results.clear()
	_pings.clear()
	_offset_usec = 0


func _on_peer_disconnected(id: int) -> void:
	if is_host() and roster.has(id):
		roster.erase(id)
		_push_lobby()
	# A racer who leaves mid-race is out where they stood; every peer marks it for itself.
	if live.has(id):
		live[id]["state"] = STATE_LEFT
	if phase == Phase.RACING and (race.get("racers", []) as Array).has(id) and not results.has(id):
		results[id] = {"name": _name_of(id), "score": int(live.get(id, {}).get("score", 0)), "left": true}
		standings_changed.emit()
	changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _register(name: String) -> void:
	if not is_host():
		return
	var id: int = multiplayer.get_remote_sender_id()
	# A WASD joiner registers twice, once on connecting and again under its WASD name: keep its pick.
	var pick: String = str((roster.get(id, {}) as Dictionary).get("suggestion", ""))
	roster[id] = {"name": _unique_name(name, id), "suggestion": pick}
	_push_lobby()


## Two players called the same thing get told apart on every screen.
func _unique_name(name: String, id: int) -> String:
	var base: String = name.strip_edges().substr(0, 20)
	if base.is_empty():
		base = "Driver"
	var taken: Array = []
	for other: int in roster:
		if other != id:
			taken.append(str(roster[other]["name"]))
	var out: String = base
	var n: int = 2
	while taken.has(out):
		out = "%s %d" % [base, n]
		n += 1
	return out


func _push_lobby() -> void:
	_set_lobby.rpc(roster, difficulty, int(phase))


@rpc("authority", "call_local", "reliable")
func _set_lobby(new_roster: Dictionary, level: String, host_phase: int) -> void:
	roster = new_roster
	difficulty = level
	# A player who joins mid-race waits in the lobby for the next one.
	if not is_host() and host_phase == Phase.LOBBY and phase != Phase.RACING:
		phase = Phase.LOBBY
	changed.emit()


# ---------------------------------------------------------------- clock offset

@rpc("any_peer", "call_remote", "unreliable")
func _ping(sent_usec: int) -> void:
	if is_host():
		_pong.rpc_id(multiplayer.get_remote_sender_id(), sent_usec, Time.get_ticks_usec())


@rpc("authority", "call_remote", "unreliable")
func _pong(sent_usec: int, host_usec: int) -> void:
	var now: int = Time.get_ticks_usec()
	var rtt: int = now - sent_usec
	# The host read its clock about half a round trip before this arrived.
	_pings.append([rtt, host_usec + rtt / 2 - now])
	if _pings.size() > PING_KEEP:
		_pings.pop_front()
	var best: Array = _pings[0]
	for sample: Array in _pings:
		if int(sample[0]) < int(best[0]):
			best = sample
	_offset_usec = int(best[1])


## The host's clock reading now, on this computer.
func host_usec() -> int:
	return Time.get_ticks_usec() + (0 if is_host() else _offset_usec)


## The fastest recent round trip to the host in ms, or -1 before the first reply.
func ping_ms() -> int:
	if is_host() or _pings.is_empty():
		return 0 if is_host() else -1
	var best: int = int(_pings[0][0])
	for sample: Array in _pings:
		best = mini(best, int(sample[0]))
	return best / 1000


# ---------------------------------------------------------------- the vote

## Host: the level everyone plays (a song with no chart for it plays Normal, on every computer).
func set_difficulty(level: String) -> void:
	if is_host() and phase == Phase.LOBBY:
		difficulty = level
		_push_lobby()


func suggest(song_id: String) -> void:
	if phase != Phase.LOBBY:
		return
	if is_host():
		_take_suggestion(1, song_id)
	else:
		_suggest.rpc_id(1, song_id)


@rpc("any_peer", "call_remote", "reliable")
func _suggest(song_id: String) -> void:
	if is_host():
		_take_suggestion(multiplayer.get_remote_sender_id(), song_id)


func _take_suggestion(id: int, song_id: String) -> void:
	var song: Dictionary = SongLibrary.find(song_id)
	if not roster.has(id) or song.is_empty() or str(song.get("source", "")) == "imported":
		return
	roster[id]["suggestion"] = song_id
	_push_lobby()


func suggestions() -> Array:
	var out: Array = []
	for id: int in roster:
		var s: String = str(roster[id].get("suggestion", ""))
		if not s.is_empty():
			out.append(s)
	return out


func can_draw() -> bool:
	return is_host() and phase == Phase.LOBBY and roster.size() >= 2 and not suggestions().is_empty()


## Host: draws one of the suggestions and starts the race REVEAL_SECONDS + LEAD_SECONDS from now.
func draw() -> void:
	if not can_draw():
		return
	var pool: Array = suggestions()
	var song_id: String = str(pool[randi() % pool.size()])
	var song: Dictionary = SongLibrary.find(song_id)
	var level: String = difficulty if SongLibrary.has_level(song, difficulty) else "normal"
	var zero: int = Time.get_ticks_usec() + int((REVEAL_SECONDS + LEAD_SECONDS) * 1000000.0)
	if transport == "wasd" and _wasd():
		_wasd().set_lobby({"locked": true})
	_begin.rpc(song_id, level, pool, zero, roster.keys())


@rpc("authority", "call_local", "reliable")
func _begin(song_id: String, level: String, pool: Array, zero_host: int, racers: Array) -> void:
	if not racers.has(me()):
		return  # joined after the draw: the next race
	race = {"song": song_id, "level": level, "suggestions": pool, "zero": zero_host, "racers": racers}
	live.clear()
	results.clear()
	for id: int in racers:
		live[id] = {"name": _name_of(id), "score": 0, "combo": 0, "fuel": 1.0, "hits": 0, "misses": 0, "progress": 0.0,
			"hit_lanes": 0, "miss_lanes": 0, "state": STATE_DRIVING, "at": Time.get_ticks_usec()}
	_hit_mask = 0
	_miss_mask = 0
	_send_left = 0.0
	phase = Phase.RACING
	changed.emit()
	race_starting.emit(song_id, level, pool, zero_host - (0 if is_host() else _offset_usec))


# ---------------------------------------------------------------- the race

## Every frame of this player's run: the numbers, and which lanes were hit or missed since the last call.
func report(score: int, combo: int, fuel: float, hits: int, misses: int, progress: float, hit_lanes: int,
		miss_lanes: int, out: bool, delta: float) -> void:
	if phase != Phase.RACING or not live.has(me()):
		return
	var mine: Dictionary = live[me()]
	mine.merge({"score": score, "combo": combo, "fuel": fuel, "hits": hits, "misses": misses, "progress": progress,
		"hit_lanes": hit_lanes, "miss_lanes": miss_lanes, "at": Time.get_ticks_usec()}, true)
	if out and int(mine["state"]) == STATE_DRIVING:
		mine["state"] = STATE_OUT
	_hit_mask |= hit_lanes
	_miss_mask |= miss_lanes
	_send_left -= delta
	if _send_left > 0.0 or not _online():
		return
	_send_left = 1.0 / SEND_HZ
	_state.rpc(PackedInt32Array([score, combo, int(fuel * 1000.0), hits, misses, int(progress * 1000.0), _hit_mask,
		_miss_mask, int(mine["state"])]))
	_hit_mask = 0
	_miss_mask = 0


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(packed: PackedInt32Array) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	if phase != Phase.RACING or not live.has(id) or packed.size() < 9:
		return
	var entry: Dictionary = live[id]
	if int(entry["state"]) == STATE_DONE or int(entry["state"]) == STATE_LEFT:
		return
	entry.merge({"score": packed[0], "combo": packed[1], "fuel": packed[2] / 1000.0, "hits": packed[3],
		"misses": packed[4], "progress": packed[5] / 1000.0, "hit_lanes": packed[6], "miss_lanes": packed[7],
		"state": packed[8], "at": Time.get_ticks_usec()}, true)


## This player's run ended (finished or out of gas): every peer files the numbers.
func finish(result: Dictionary) -> void:
	if phase != Phase.RACING:
		return
	var numbers := {"name": my_name if not roster.has(me()) else str(roster[me()]["name"]),
		"score": int(result.get("score", 0)), "accuracy": float(result.get("accuracy", 0.0)),
		"grade": str(result.get("grade", "")), "failed": bool(result.get("failed", false)),
		"max_combo": int(result.get("max_combo", 0)), "perfects": int(result.get("perfects", 0)),
		"goods": int(result.get("goods", 0)), "misses": int(result.get("misses", 0)),
		"progress": float(result.get("progress", 1.0))}
	if _online():
		_finished.rpc(numbers)
	else:
		_file_result(me(), numbers)


@rpc("any_peer", "call_local", "reliable")
func _finished(numbers: Dictionary) -> void:
	var id: int = multiplayer.get_remote_sender_id()
	_file_result(id if id != 0 else me(), numbers)


func _file_result(id: int, numbers: Dictionary) -> void:
	if phase != Phase.RACING and phase != Phase.RESULTS:
		return
	results[id] = numbers
	if live.has(id):
		live[id]["score"] = int(numbers["score"])
		live[id]["state"] = STATE_OUT if bool(numbers["failed"]) else STATE_DONE
	if race_over():
		phase = Phase.RESULTS
	standings_changed.emit()


## Every racer has a result (finished, out of gas, or left).
func race_over() -> bool:
	for id: int in race.get("racers", []):
		if not results.has(id):
			return false
	return not race.is_empty()


## Racers by score, best first: [{"peer", "name", "score", "state", "result"}]. During the race the
## live numbers, then each result as it comes in.
func standings() -> Array:
	var rows: Array = []
	for id: int in live:
		var entry: Dictionary = live[id]
		rows.append({"peer": id, "name": _name_of(id), "score": int(results.get(id, entry).get("score", 0)),
			"state": int(entry["state"]), "result": results.get(id, {}), "me": id == me()})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		# Someone who left goes last; otherwise the higher score, and on a tie the lower peer id.
		var a_left: bool = int(a["state"]) == STATE_LEFT
		var b_left: bool = int(b["state"]) == STATE_LEFT
		if a_left != b_left:
			return b_left
		if int(a["score"]) != int(b["score"]):
			return int(a["score"]) > int(b["score"])
		return int(a["peer"]) < int(b["peer"]))
	return rows


## Host: everyone back to the lobby, suggestions cleared, for the next race.
func back_to_lobby() -> void:
	if not is_host():
		return
	for id: int in roster:
		roster[id]["suggestion"] = ""
	if transport == "wasd" and _wasd():
		_wasd().set_lobby({"locked": false})
	_to_lobby.rpc()


@rpc("authority", "call_local", "reliable")
func _to_lobby() -> void:
	race.clear()
	live.clear()
	results.clear()
	phase = Phase.LOBBY
	if is_host():
		_push_lobby()
	changed.emit()


func _name_of(id: int) -> String:
	if roster.has(id):
		return str(roster[id]["name"])
	if live.has(id):
		return str(live[id].get("name", "Driver"))
	return "Driver"

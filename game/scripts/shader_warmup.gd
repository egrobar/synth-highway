class_name ShaderWarmup
extends Node
## Compiles a region world's shaders a few a frame, off screen, before its props are drawn.
## Compatibility renderer only (the web build): ThemeWorld.setup() starts one; desktop never does.
##
## Why: the web build froze at start (WASD Engine web check, 2026-11-19: 2.9 s; 5.2 s in a fresh
## Chromium, 2.3 s of it waiting on the 42 shader programs the first title frame compiled at once).
## The Compatibility renderer (WebGL 2) compiles a program the first time it draws a material in each
## pass (depth prepass, colour, shadow map) and form (one mesh, or a MultiMesh or particles), and the
## browser waits on each, ~55 ms apiece on a fast Mac. What was out of view at first compiled later,
## mid-song, as it came into view.
##
## How: every prop with a material not yet drawn this session goes on HIDDEN_LAYER, which no camera
## draws and no light shadows, and a tiny SubViewport sharing the world draws a stand-in for each
## material, far below the road: the prop's own mesh with that material, in the same form (MultiMesh or
## not) and shadow setting, lit by the same lights (ThemeWorld._steady_shader_variants() makes the
## light mix the same everywhere). A prop goes back on its own layers once all its materials have been
## drawn, and the road's view is given only a few materials it has not shown before each frame (the
## browser still builds a GPU pipeline for each there), so the world fills in over the first second
## or two on a cold start; a browser that keeps the programs from an earlier visit finishes in a few
## frames, as the batch grows while frames stay fast.
## Hidden props (event effects) are warmed too, so a milestone's fireworks do not stall the song.

## Props waiting on their shaders. No camera draws this layer and no light shadows it. 1-based.
const HIDDEN_LAYER := 20
## The stand-ins, drawn only by the warm-up camera. 1-based.
const STAGE_LAYER := 19
## Far below the road and out of the road camera's view, but inside the steady lights' reach.
const STAGE_AT := Vector3(0.0, -1500.0, 13.6)
## The frame time to aim for: each frame does as much as the last such frame's cost per unit says
## will fit (see _process()). Compiles are what cost; a stand-in whose shader is already compiled
## (most materials share a few shaders) is nearly free.
const TARGET_FRAME := 0.1
const MAX_BATCH := 64
## Units (see _reveal()) a frame may spend showing props.
const MAX_REVEAL := 512

## What has been drawn this session: "<material id>|<instanced>|<casts shadow>". Compiled programs
## outlive the world that needed them (until their material is freed), so a region visited again, or
## rebuilt for a wider road, only warms what is new.
static var _drawn: Dictionary = {}
## The same keys, once a prop using them has been shown in the road's own view.
static var _shown: Dictionary = {}
## The last frame a warm-up did work in (only one does, each frame).
static var _worked_frame: int = -1

var _queue: Array[Dictionary] = []
var _queued: Dictionary = {}
## Props on HIDDEN_LAYER: {"node": GeometryInstance3D, "layers": int, "keys": Array[String]}.
var _waiting: Array[Dictionary] = []
var _viewport: SubViewport
var _stage: Node3D
## Stand-ins added last frame, drawn by the time this frame runs: [[node, key], ...].
var _showing: Array = []
var _batch: int = 2
var _last_batch: int = 0
var _reveal_batch: int = 4
var _last_reveal: int = 0
var _last_tick: int = 0
var _frames: int = 0
## How long the world took to build, for the log line at the end.
var built_ms: int = 0
var _free_when_done: bool = false
var _done: bool = false
var _started_at: int = 0


func start(world: Node3D) -> void:
	_started_at = Time.get_ticks_msec()
	var camera: Camera3D = world.get_viewport().get_camera_3d()
	if camera:
		camera.set_cull_mask_value(HIDDEN_LAYER, false)
		camera.set_cull_mask_value(STAGE_LAYER, false)
	for node: Node in world.find_children("*", "Light3D", true, false):
		(node as Light3D).shadow_caster_mask &= ~(1 << (HIDDEN_LAYER - 1))
	for node: Node in world.find_children("*", "GeometryInstance3D", true, false):
		_consider(node as GeometryInstance3D, true)
	_open_stage()


## Draws stand-ins for every material under `root` and in its own script variables, hiding nothing,
## and frees itself when done: for the highway (Stage.show_chart()), whose keys must show at once and
## whose notes and hit effects take their materials as the song goes (a compile when the first sharp
## or power chord came into view, or at the first hit's burst, stalled the frame that times the
## player's next key press).
func prewarm(root: Node) -> void:
	_started_at = Time.get_ticks_msec()
	_free_when_done = true
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		_consider(node as GeometryInstance3D, false)
	var box := BoxMesh.new()
	for property: Dictionary in root.get_property_list():
		if not (int(property["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var value: Variant = root.get(property["name"])
		var held: Array = [value] if value is Material else (value as Array if value is Array else [])
		for mat: Variant in held:
			if mat is Material:
				_need(mat as Material, box, false, false)
	_open_stage()


func _open_stage() -> void:
	if _queue.is_empty():
		_finish()
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(64, 64)
	# Drawn only in frames that have stand-ins: otherwise its first frame compiled the sky, glow and
	# tone-mapping shaders in the same frame as the world's build.
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	# The same render target settings as the road's view (a browser builds a GPU pipeline per program
	# and target, multisampling included), so the stand-ins' pipelines match the road's where they can.
	# Showing a material in the road's view still cost a cold browser time, hence _reveal()'s budget.
	var main: Viewport = get_viewport()
	_viewport.msaa_3d = main.msaa_3d
	_viewport.use_hdr_2d = main.use_hdr_2d
	_viewport.use_debanding = main.use_debanding
	add_child(_viewport)
	var eye := Camera3D.new()
	# Every layer but the waiting props': a camera only uses the lights on layers it draws (a light's
	# own `layers`, 1 by default), and drawn unlit the stand-ins compiled variants nothing else uses.
	# Down here it sees nothing but the stand-ins.
	eye.cull_mask = 0xFFFFF & ~(1 << (HIDDEN_LAYER - 1))
	eye.position = STAGE_AT
	eye.far = 50.0
	_viewport.add_child(eye)
	eye.current = true
	_stage = Node3D.new()
	_stage.position = STAGE_AT + Vector3(0.0, 0.0, -4.0)
	_viewport.add_child(_stage)


func done() -> bool:
	return _done


func _process(delta: float) -> void:
	if _done:
		return
	# Last frame's stand-ins have been drawn (the frame is rendered after every node's _process).
	for shown: Array in _showing:
		_drawn[shown[1]] = true
		(shown[0] as Node).queue_free()
	_showing.clear()
	if _queue.is_empty() and _waiting.is_empty():
		_finish()
		return
	# The world's first frame already compiles the sky, glow, tone mapping and interface shaders.
	_frames += 1
	if _frames == 1:
		return
	# Two budgets, each sized from the last frame that spent it: stand-ins drawn, and props shown in
	# the road's view. In a browser the second is what costs (stand-ins drawn cheaply, then everything
	# shown at once, a cold Tidewater spent 0.9 s in one frame), so a frame that shows props draws no
	# stand-ins. Timed by the clock: in a browser `delta` is smoothed, and read 110-145 ms for frames
	# that took 240-500 ms. A budget at most doubles a frame, as a cheap frame can be followed by a
	# browser catching up on the last one's GPU work.
	var now: int = Time.get_ticks_usec()
	var took: float = maxf(float(now - _last_tick) / 1000000.0 if _last_tick > 0 else delta, 0.001)
	_last_tick = now
	if _last_reveal > 0:
		var fits: int = int(TARGET_FRAME / (took / float(_last_reveal)))
		_reveal_batch = clampi(fits, 1, mini(_reveal_batch * 2, MAX_REVEAL))
	elif _last_batch > 0:
		var fits_stand_ins: int = int(TARGET_FRAME / (took / float(_last_batch)))
		_batch = clampi(fits_stand_ins, 1, mini(_batch * 2, MAX_BATCH))
	_last_batch = 0
	_last_reveal = 0
	# One warm-up works a frame: a world and a highway built together (a drive into another region)
	# each spent a full budget in the same frame, a 1.1 s frame on a cold Ring Road.
	var frame: int = Engine.get_process_frames()
	if _worked_frame == frame:
		return
	_worked_frame = frame
	_last_reveal = _reveal(_reveal_batch)
	if _queue.is_empty() or _last_reveal > 0:
		return
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	while _last_batch < _batch and not _queue.is_empty():
		var need: Dictionary = _queue.pop_front()
		if _drawn.has(need["key"]):
			continue
		var stand_in: GeometryInstance3D = _stand_in(need)
		stand_in.layers = 1 << (STAGE_LAYER - 1)
		_stage.add_child(stand_in)
		_showing.append([stand_in, need["key"]])
		_last_batch += 1


## Puts a prop's materials on the warm-up's list if not yet drawn in its form; with `hide`, the prop
## waits on HIDDEN_LAYER until they have been.
func _consider(node: GeometryInstance3D, hide: bool) -> void:
	var mesh: Mesh = null
	var instanced: bool = false
	if node is MeshInstance3D:
		mesh = (node as MeshInstance3D).mesh
	elif node is MultiMeshInstance3D:
		var multi: MultiMesh = (node as MultiMeshInstance3D).multimesh
		mesh = multi.mesh if multi else null
		instanced = true
	elif node is CPUParticles3D:
		mesh = (node as CPUParticles3D).mesh
		instanced = true
	if mesh == null:
		return
	var shadow: bool = node.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var keys: Array[String] = []
	for mat: Material in _materials(node, mesh):
		var key: String = _need(mat, mesh, instanced, shadow)
		if not key.is_empty():
			keys.append(key)
	if keys.is_empty() or not hide:
		return
	_waiting.append({"node": node, "layers": node.layers, "keys": keys})
	node.layers = 1 << (HIDDEN_LAYER - 1)


## Queues one material in one form unless already drawn; returns its key, or "" if already drawn.
func _need(mat: Material, mesh: Mesh, instanced: bool, shadow: bool) -> String:
	var key: String = "%d|%s|%s" % [mat.get_instance_id(), instanced, shadow]
	if _drawn.has(key):
		return ""
	if not _queued.has(key):
		_queued[key] = true
		_queue.append({"key": key, "material": mat, "mesh": mesh, "instanced": instanced, "shadow": shadow})
	return key


## Every material the node draws with, next passes included.
func _materials(node: GeometryInstance3D, mesh: Mesh) -> Array[Material]:
	var found: Array[Material] = []
	var first: Array[Material] = []
	if node.material_override:
		first.append(node.material_override)
	else:
		for s: int in mesh.get_surface_count():
			var mat: Material = null
			if node is MeshInstance3D:
				mat = (node as MeshInstance3D).get_active_material(s)
			else:
				mat = mesh.surface_get_material(s)
			if mat:
				first.append(mat)
	if node.material_overlay:
		first.append(node.material_overlay)
	for mat: Material in first:
		var pass_mat: Material = mat
		while pass_mat and not found.has(pass_mat):
			found.append(pass_mat)
			pass_mat = pass_mat.next_pass
	return found


## The prop's own mesh drawn with one material, in its form and shadow setting, about a metre across.
func _stand_in(need: Dictionary) -> GeometryInstance3D:
	var mesh: Mesh = need["mesh"]
	var node: GeometryInstance3D
	if need["instanced"]:
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh
		multi.instance_count = 1
		# A new instance's transform is all zeros: no size, so culled, and nothing compiled.
		multi.set_instance_transform(0, Transform3D.IDENTITY)
		var batch := MultiMeshInstance3D.new()
		batch.multimesh = multi
		node = batch
	else:
		var single := MeshInstance3D.new()
		single.mesh = mesh
		node = single
	node.material_override = need["material"]
	node.cast_shadow = (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if need["shadow"]
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var box: AABB = mesh.get_aabb()
	var size: float = maxf(maxf(box.size.x, box.size.y), maxf(box.size.z, 0.001))
	var fit: float = 1.0 / size
	(node as Node3D).scale = Vector3.ONE * fit
	(node as Node3D).position = -box.get_center() * fit
	return node


## Puts props whose materials have all been drawn back on their own layers, in build order, spending
## at most `budget` units: one per prop shown, and one more per material the road's view has not
## shown yet. Both cost a cold browser time on their first draw there (a prop's buffers, a material's
## pipeline): shown all at once, Ring Road's ~800 draws took a 1.2 s frame. Returns the units spent.
func _reveal(budget: int) -> int:
	var spent: int = 0
	var i: int = 0
	while i < _waiting.size():
		var entry: Dictionary = _waiting[i]
		var all_drawn: bool = true
		var fresh: Array[String] = []
		for key: String in entry["keys"]:
			if not _drawn.has(key):
				all_drawn = false
				break
			if not _shown.has(key):
				fresh.append(key)
		var node: GeometryInstance3D = entry["node"]
		var cost: int = 1 + fresh.size()
		# A hidden prop (an event effect) costs nothing to put back, and has shown nothing yet.
		if is_instance_valid(node) and not node.is_visible_in_tree():
			fresh.clear()
			cost = 0
		# Over budget waits for a later frame, but each frame shows at least one prop.
		if not all_drawn or (spent > 0 and spent + cost > budget):
			i += 1
			continue
		for key: String in fresh:
			_shown[key] = true
		spent += cost
		if is_instance_valid(node):
			node.layers = int(entry["layers"])
		_waiting.remove_at(i)
	return spent


func _finish() -> void:
	_done = true
	for entry: Dictionary in _waiting:
		var node: GeometryInstance3D = entry["node"]
		if is_instance_valid(node):
			node.layers = int(entry["layers"])
	_waiting.clear()
	if _viewport:
		_viewport.queue_free()
		_viewport = null
	if _free_when_done:
		print("ShaderWarmup: %d highway materials warmed in %d ms over %d frames" % [_queued.size(),
			Time.get_ticks_msec() - _started_at, _frames])
		queue_free()
	else:
		print("ShaderWarmup: world built in %d ms, %d materials warmed in %d ms over %d frames" % [built_ms,
			_queued.size(), Time.get_ticks_msec() - _started_at, _frames])

class_name RouteScreen
extends Control
## The song-select screen: a region skin (RouteSkin) drawn in the design's 1280x720 space,
## scaled to fit the window and centred, with the leftover filled in the skin's ground colour.
##
## main.gd builds the model and handles the keyboard exactly as before; this control only
## draws and turns clicks into `acted` signals (see RouteSkin for the model and the actions).

signal acted(action: String, arg: Variant)

const DESIGN := Vector2(1280.0, 720.0)

var skin: RouteSkin
var model: Dictionary = {}
var _hits: Array = []
var _scale: float = 1.0
var _origin := Vector2.ZERO
## The design-space scale and the transform drawing is going through, for RouteSkin.draw_text,
## which draws text at its on-screen size so it stays sharp.
var draw_scale: float = 1.0
var draw_matrix := Transform2D.IDENTITY


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Halftones, dot screens and stripes are tiled textures.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func present(new_skin: RouteSkin, new_model: Dictionary) -> void:
	skin = new_skin
	model = new_model
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if skin == null:
		return
	_scale = minf(size.x / DESIGN.x, size.y / DESIGN.y)
	_origin = (size - DESIGN * _scale) * 0.5
	draw_rect(Rect2(Vector2.ZERO, size), skin.ground)
	draw_scale = _scale
	_set_matrix(Transform2D(0.0, Vector2(_scale, _scale), 0.0, _origin))
	_hits.clear()
	skin.draw(self, model)
	_set_matrix(Transform2D.IDENTITY)
	draw_scale = 1.0


## Draws what follows through an extra transform in design space (a rotated label, a skewed
## run of text); end with end_local().
func begin_local(local: Transform2D) -> void:
	_set_matrix(Transform2D(0.0, Vector2(_scale, _scale), 0.0, _origin) * local)


func end_local() -> void:
	_set_matrix(Transform2D(0.0, Vector2(_scale, _scale), 0.0, _origin))


func _set_matrix(matrix: Transform2D) -> void:
	draw_matrix = matrix
	draw_set_transform_matrix(matrix)


## Registers a clickable area in design space. Later areas win where they overlap.
func hit(rect: Rect2, action: String, arg: Variant = null) -> void:
	_hits.append([rect, action, arg])


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _hit_at(event.position).size() > 0 else Control.CURSOR_ARROW
	elif event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var found: Array = _hit_at(event.position)
		if found.size() > 0:
			accept_event()
			acted.emit(found[1], found[2])


func _hit_at(screen_point: Vector2) -> Array:
	var p: Vector2 = (screen_point - _origin) / _scale
	for i: int in range(_hits.size() - 1, -1, -1):
		if (_hits[i][0] as Rect2).has_point(p):
			return _hits[i]
	return []

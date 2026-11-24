extends SceneTree
## Cuts the battle items' icon sheet (sources/art/items/item_sheet.png, made with Nano Banana:
## a 4 x 3 grid of tiles on black) into one 256 px icon per item, game/assets/textures/items/<id>.png.
## Each tile is found by its glowing edge inside its grid cell, so an uneven grid still cuts cleanly.
## Run: tools/godot.sh --headless -s ../tools/items/slice_icons.gd   (from the repo root)

const ORDER := ["paint", "quake", "disco", "fog", "turbo", "blackout", "wobble", "leak", "nitro", "shield", "mystery", "empty"]
const COLUMNS := 4
const ROWS := 3
const SIZE := 256


func _init() -> void:
	var root: String = ProjectSettings.globalize_path("res://").path_join("..")
	var sheet := Image.load_from_file(root.path_join("sources/art/items/item_sheet.png"))
	if sheet == null:
		push_error("No item sheet")
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)
	var cell := Vector2(sheet.get_width() / float(COLUMNS), sheet.get_height() / float(ROWS))
	var out_dir: String = ProjectSettings.globalize_path("res://assets/textures/items")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for i: int in ORDER.size():
		var origin := Vector2i(int((i % COLUMNS) * cell.x), int((i / COLUMNS) * cell.y))
		var size := Vector2i(int(cell.x), int(cell.y))
		var lo := Vector2i(size)
		var hi := Vector2i(-1, -1)
		# Scan inside a margin: a tile's glow can spill a few pixels over its cell's line.
		var margin: int = 24
		for y: int in range(margin, size.y - margin, 2):
			for x: int in range(margin, size.x - margin, 2):
				var c: Color = sheet.get_pixel(origin.x + x, origin.y + y)
				if maxf(c.r, maxf(c.g, c.b)) > 0.1:
					lo = Vector2i(mini(lo.x, x), mini(lo.y, y))
					hi = Vector2i(maxi(hi.x, x), maxi(hi.y, y))
		if hi.x < 0:
			push_error("Empty cell %d" % i)
			continue
		# Square, centred on the tile, so the rounded tile keeps its shape.
		var side: int = maxi(hi.x - lo.x, hi.y - lo.y) + 6
		var centre: Vector2i = origin + (lo + hi) / 2
		var rect := Rect2i(centre - Vector2i(side, side) / 2, Vector2i(side, side)).intersection(Rect2i(Vector2i.ZERO, sheet.get_size()))
		var icon: Image = sheet.get_region(rect)
		icon.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		icon.save_png(out_dir.path_join("%s.png" % ORDER[i]))
		print("ICON ", ORDER[i], " ", rect)
	quit()

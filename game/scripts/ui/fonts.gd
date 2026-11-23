class_name Fonts
extends RefCounted
## The bundled typefaces, by family name, with weight and letter-spacing variants made once.
##
## Files live in res://assets/fonts/ (Google Fonts, SIL Open Font License; licences in
## res://assets/fonts/licenses/). Each region's menu skin uses its own families (see the
## Song Select Redesigns canvas, 2026-11-11): Red Frontier Alfa Slab One, Rye, Oswald and
## Courier Prime; Neon Sprawl Anton, Space Grotesk and JetBrains Mono; Tidewater DM Serif
## Display and Manrope; Io Burn Saira Stencil One, VT323 and Oswald; Ring Road Outfit and
## Azeret Mono.

const FILES := {
	"Alfa Slab One": "AlfaSlabOne-Regular.ttf",
	"Rye": "Rye-Regular.ttf",
	"Courier Prime": "CourierPrime-Bold.ttf",
	"Oswald": "Oswald-Variable.ttf",
	"Anton": "Anton-Regular.ttf",
	"Space Grotesk": "SpaceGrotesk-Variable.ttf",
	"JetBrains Mono": "JetBrainsMono-Variable.ttf",
	"DM Serif Display": "DMSerifDisplay-Regular.ttf",
	"DM Serif Display Italic": "DMSerifDisplay-Italic.ttf",
	"Manrope": "Manrope-Variable.ttf",
	"Saira Stencil One": "SairaStencilOne-Regular.ttf",
	"VT323": "VT323-Regular.ttf",
	"Outfit": "Outfit-Variable.ttf",
	"Azeret Mono": "AzeretMono-Variable.ttf",
}

static var _files: Dictionary = {}
static var _variants: Dictionary = {}


## `family` at a CSS-style `weight` (variable fonts only; fixed-weight files ignore it) with
## `spacing` extra pixels between letters (CSS letter-spacing, rounded to whole pixels).
static func get_font(family: String, weight: int = 400, spacing: float = 0.0) -> Font:
	var key: String = "%s|%d|%d" % [family, weight, int(round(spacing))]
	if _variants.has(key):
		return _variants[key]
	if not _files.has(family):
		assert(FILES.has(family), "Unknown font family: " + family)
		_files[family] = load("res://assets/fonts/" + str(FILES[family]))
	var variant := FontVariation.new()
	variant.base_font = _files[family]
	if weight != 400:
		variant.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	if spacing != 0.0:
		variant.spacing_glyph = int(round(spacing))
	_variants[key] = variant
	return variant


static var _scaled: Dictionary = {}


## `font` for drawing `scale` times larger (RouteSkin.draw_text): letter spacing is whole pixels
## at whatever size is drawn, so a variant drawn bigger needs its spacing scaled to keep the
## design's tracking (to the nearest pixel, or rounded down with `down`, for text that must not
## come out wider than it measured). Fonts without extra spacing come back as they are.
static func spaced_for_scale(font: Font, scale: float, down: bool = false) -> Font:
	var variant := font as FontVariation
	if variant == null or variant.spacing_glyph == 0:
		return font
	var spacing: int = floori(variant.spacing_glyph * scale) if down else int(round(variant.spacing_glyph * scale))
	var key: String = "%d|%d" % [font.get_instance_id(), spacing]
	if not _scaled.has(key):
		var bigger: FontVariation = variant.duplicate() as FontVariation
		bigger.spacing_glyph = spacing
		_scaled[key] = bigger
	return _scaled[key]

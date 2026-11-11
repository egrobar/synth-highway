# Regions

A region is a theme on the night-drive map, matched to a music genre. Each one is a self-contained set
of files, so regions can be built at the same time without touching each other. **Backroads is the
reference implementation**: copy its patterns.

| Order | id | Name | Genres | Radio stations (tools/importer/radio_manifest.tsv) |
|---|---|---|---|---|
| 1 | `backroads` | Red Frontier | Country, folk, driving | Frontier Radio |
| 2 | `neon` | Neon Sprawl | Synthwave, heavy electronic | Fusion FM, Redline |
| 3 | `coast` | Tidewater | Pop, sea shanties | Nebula One, Void Hoppers |
| 4 | `mesa` | Io Burn | Alt, punk, the strange stuff | D43D |
| 5 | `aurora` | Ring Road | Classical, choral | Core Klassik, Hymns of the Ark |

Region ids are kept from the first, Earth-bound version of the route so every chart still points
at the right region; only names and looks changed in the sci-fi rework (2026-11-10).

## Files a region owns (and nothing else)

| File | Made with | Produces |
|---|---|---|
| `tools/themes/<id>/props.py` | Blender, via `tools/blender/propkit.py` | `game/assets/themes/<id>/models/*.glb` |
| `tools/themes/<id>/textures.py` | GIMP, via `tools/gimp/paintkit.py` | `game/assets/themes/<id>/textures/` (`sky.png`, road and ground tiles, `region_logo.png`) |
| `tools/themes/<id>/ambience.scd` | SuperCollider | `game/assets/themes/<id>/audio/ambience.wav` (looped) |
| `tools/song/songs/<song>.py` | `tools/song/songlib.py` | `game/data/songs/<song>.json` and `game/assets/songs/<song>/{backing,lead}.wav` |
| `tools/song/synths/<id>.scd` (optional) | SuperCollider | extra instruments, appended to `~defs` |
| `game/scripts/themes/<id>.gd` | `extends ThemeWorld` | the 3D world |
| `game/data/themes/<id>.json` | by hand | name, genres, order, lead, accent colour, one-line blurb |

**Do not edit shared files** (`main.gd`, `play_session.gd`, `judge.gd`, `highway.gd`, `stage.gd`,
`theme_world.gd`, `chart.gd`, `songlib.py`, `synths/core.scd`, `propkit.py`, `paintkit.py`,
`render_*.scd`, `build_assets.sh`). If a helper is missing, write it in your region's own files and say
so in your report.

## Build and check

```bash
tools/build_assets.sh <region-id> <song-id> ...   # ONLY your ids; no arguments rebuilds everything
tools/godot.sh --headless -s res://tests/bot_song.gd -- --song=<song> --difficulty=normal   # prints RESULT
tools/godot.sh --always-on-top --position 40,40 -s res://tests/preview.gd -- --theme=<id> --song=<song> --at=30 --out=/abs/path.png
tools/godot.sh --always-on-top --position 40,40 -s res://tests/preview.gd -- --theme=<id> --out=/abs/empty_road.png
```

Always run Godot through `tools/godot.sh`: it serialises Godot runs, because two processes importing at
once corrupt the import cache. On macOS a game window must be `--always-on-top`, or it renders black.
Look at your screenshots: check the notes and keyboard stay readable, the hood frames the bottom edge,
and nothing in the scene sits on the road.

## World script (`game/scripts/themes/<id>.gd`)

Override `build()` and use the helpers in `game/scripts/theme_world.gd`:
`make_environment({...})`, `make_ground(tex, tint, tiles, look)`, `make_road(tex, tint, edge_colour, edge_glow, look)`,
`make_vehicle(hood_glb, beam_colour, energy)`, `row(glb, x, spacing, count)` and `repeat(...)` for
things that tile along the road, `scatter(glb, per_tile, x_from, x_to)` for thousands of small things,
`landmarks([[model, side, distance_from_edge, along, scale], ...])` for big props that come round,
`drifters(colour, amount, height, spread_x, velocity)` for fireflies, rain, snow or embers,
`add_light(light, energy)` for any light that should dim with the fuel gauge, `asset("models/x.glb")`.
You may override `_process(delta)` for animation (blinking signs, lightning), but call `super(delta)`.
Never put anything on the road itself (|x| < road_half), and keep the area right in front of the keys
dark enough that the cyan notes read. The player's notes are always cyan in every region.

### High-detail graphics (2026-11-10)

With the "High-detail graphics" setting on (the default; `Settings.high_graphics`), every region gets
the same heavy stack from ThemeWorld, so a region only tunes it:

- **Lighting** (`_heavy_rendering`): key-light shadows (two splits to 110 m), SSAO, SSIL, screen-space
  reflections and a volumetric haze the headlight beams show in. Tune the haze per region in
  `make_environment`: `haze` (density, about 0.001 for clean air to 0.009 for rain), `haze_color`,
  `haze_glow`; `ao` for ambient occlusion strength. Keys and notes never cast or receive shadows.
- **Road and ground** are `shaders/surface.gdshader`: relief derived from your painted tile, fine grain,
  slow colour variation, and for the ground a rotated second copy that hides the tiling. `look` keys:
  `roughness`, `specular`, `metallic`, `roughness_texture`, `bump`, `grain`, `macro`, `wetness`
  (0 to 1: damp patches and mirror puddles), `puddle_tint`, `anti_tile`. Paint the tile with real
  value contrast in cracks and seams: dark reads as low.
- **Props** are weathered by `shaders/prop_detail.gdshader` after `build()`: set `weathering` in
  `build()` (`grime_color`, `grime`, `grime_height`, `dust_color`, `dust`, `grain`, `mottle`). Glowing,
  see-through and unshaded materials are left alone; mark a node `set_meta("no_weathering", true)` to
  keep it clean (the hood is).
- Frame rate comes first: timing reads input once a frame. Measure with `godot_performance` after a
  change, and keep shadow casters lean (no shadows on headlights; tiny scatter casts are fine).

## Props (`props.py`)

1 unit = 1 game unit, origin on the ground at the centre, Blender +Y is down the road. Lit, road-facing
sides go on Blender **-X**. A repeating prop is exactly one repeat long, and its spacing constant must
match the world script. Every region needs a `hood` model, the player's vehicle seen from the driver's
seat: copy `hood()` from `tools/themes/backroads/props.py`, keep its footprint (half-width 8, running
toward -Y about 9.6, top from 0 to about 0.95, lamps at the front corners), and change the styling.
Model low-poly (under about 1,500 triangles each before the finish). `export_all` then gives every
prop a hard-surface finish (`propkit.detail`): 3 cm two-segment bevels on edges sharper than 35°,
hardened area-weighted normals and smooth shading, so corners catch the light. Set
`obj["bevel"] = 0` on a model that must stay razor-edged, or a width in metres to change it.

## Textures (`textures.py`)

`from paintkit import *`, `set_out("game/assets/themes/<id>/textures")`. The sky is a 4096×2048
equirectangular panorama: horizon at half height, the centre column is straight down the road, and
anything you want in shot sits a little above the horizon (the camera looks slightly down). GIMP 3 hides
`gegl:linear-gradient` from scripts, so use `gradient()`. Colours given as `"rgb(...)"` are read as
**linear** light and come out pale: pick colours with `srgb(r, g, b)` from paintkit instead. `Gimp.Drawable.threshold` works but warns.
Fonts come from macOS (`pick_font` takes a fallback list).

## Songs (`tools/song/songs/<song>.py`)

Copy `county_line.py`. Write **original** music only: no melodies, lyrics or titles from existing
songs, except public-domain pieces (Aurora Pass). `Song(id, title, theme, bpm, lead_patch)`,
`song.hit(t, instrument, midi, seconds, amp, pan)` for backing, `song.melody(bar, ["E4:1 G4:0.5 r:1", ...])`
for the lead (durations in beats), `song.section(name, bar)`, `song.write(bars)`.

- Players use the home row, `A S D F G H J K L ;`, for every song. `songlib.write_chart` maps the
  melody onto those lanes for you: one scale step per lane, higher notes further right, notes outside
  the window folded by an octave (it prints how many). Write in any key and range. A melody within
  eight scale steps stays on the eight resting keys; a wider one adds G and H (index-finger reaches).
  Easy always uses the eight resting keys. The audio always plays exactly what you wrote.
- Notes of 0.75 s or longer are holds. Aim for a quarter to a third of the notes as holds.
- Difficulty climbs along the map. County Line (region 1) is about 0.9 notes a second on Normal.
  Region 2 about 1.2 to 1.6, region 3 1.5 to 2, region 4 2 to 2.6, region 5 varies by piece. Never
  write two notes closer than 0.12 s.
- Songs run 75 to 120 seconds, with a 2 to 4 bar intro before the first melody note.
- Instruments in `tools/song/synths/core.scd`: pick, bass, synthbass, organ, piano, epiano, pad, arp,
  power, bell, kick, snare, brush, hat, shaker, crash, tom, and the leads steel, sawlead, drive, flute.
  Every instrument takes midi, sus, amp and pan.
- The perfect bot must get an S on both difficulties (`bot_song.gd` exits non-zero otherwise).

## The sci-fi route (2026-11-10)

The songs come from Evan's space game's radio stations, so the drive leaves Earth. Each region keeps
its genre and its id, and gets a sci-fi look. Neon Sprawl stays as it is.

- **Red Frontier** (`backroads`): a Mars homestead at dusk. Rust-red plains and dunes; rows of
  glowing greenhouse domes and crop tubes where the wheat was (keep a scatter of something low);
  power pylons with cables instead of telephone poles; pressurised habitat modules with warm lit
  windows; water-ice silos; a parked cargo shuttle or a landing pad with beacons; wind or dust
  turbines. Sky: butterscotch-pink with the sunset's blue glow (Mars sunsets are blue), two small
  moons, a bright Earth "star". Dust devils or drifting dust motes. Vehicle: a pressurised rover hood.
- **Tidewater** (`coast`): the shore of an ocean moon. Dark sea with drifting ice floes; a giant
  banded gas giant low over the horizon, its light on the water; beacon towers instead of
  lighthouses; floating habitat platforms with lights; ice cliffs on the land side; occasional
  cryo-geyser plumes. Vehicle: a sleek hover-convertible hood.
- **Io Burn** (`mesa`): a volcanic moon. Black basalt road; sulphur-yellow and orange plains;
  glowing lava rivers and vents; erupting plumes; mining rigs and warning beacons; Jupiter huge in
  the sky. Heat shimmer or embers. Vehicle: an armoured hauler hood.
- **Ring Road** (`aurora`): a highway along an orbital ring. Saturn and its rings fill the sky;
  a glass-sided skyway with structural ribs; solar arrays; observation domes; docking arms with
  blinking lights; a star field. Calm, clean, white and green light. Vehicle: a transit pod hood.

Keep everything else from the contract above: notes and keys stay readable, nothing on the road,
the hood frames the bottom edge, the region must look clearly unlike the other four.

## Machine rules (Evan's Mac: 24 GB, Docker holds 16 GB)

- Every Blender, GIMP or SuperCollider build runs through the machine-wide heavy-job lock:
  `~/Desktop/siege-pc/tools/heavy.sh --max-gb 6 --timeout 1200 --name synth-<id> -- tools/build_assets.sh <id>`.
  Exit 75 means it never started (memory short or lock busy): wait and retry. Exit 137 means it was
  killed for memory: do not rerun it unchanged.
- No windowed Godot from the shell. Look at the game through the WASD Engine MCP tools (load them
  with ToolSearch "wasd-engine"), passing `project="/Users/evangrobar/Desktop/synth-highway/game"`
  on EVERY call. Builders share one WASD game slot: take `mkdir /tmp/synth-wasd.lock` before
  `godot_run` (wait while it exists) and `rmdir` it after your `godot_stop`.
- To see a region in WASD: `godot_run` (width 1600, height 900), then `godot_eval`:
  `scene._options.merge({"unlock-all": true})`, `scene.set("_region_index", <order - 1>)`,
  `scene._show_route()`; screenshot. For a drive, `scene.set("_practice_step", 1)` then
  `scene._drive_selected()`, wait, screenshot. Only practice runs: never end a run through `_finish`
  (that writes Evan's save file).
- Headless checks (`tools/godot.sh --headless -s res://tests/bot_song.gd ...`) need no lock.

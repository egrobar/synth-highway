# Regions

A region is a theme on the night-drive map, matched to a music genre. Each one is a self-contained set
of files, so regions can be built at the same time without touching each other. **Backroads is the
reference implementation**: copy its patterns.

| Order | id | Name | Genres | Lead instrument |
|---|---|---|---|---|
| 1 | `backroads` | Backroads | Country, folk, Americana | `steel` |
| 2 | `neon` | Neon Sprawl | Cyberpunk, synthwave, EDM | `sawlead` |
| 3 | `coast` | Coast Road | Pop, R&B, soul | `flute` |
| 4 | `mesa` | Red Mesa | Rock, metal, blues | `drive` |
| 5 | `aurora` | Aurora Pass | Classical, ballads, traditional | `piano` |

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
`make_environment({...})`, `make_ground(tex)`, `make_road(tex, tint, edge_colour, edge_glow)`,
`make_vehicle(hood_glb, beam_colour, energy)`, `row(glb, x, spacing, count)` and `repeat(...)` for
things that tile along the road, `scatter(glb, per_tile, x_from, x_to)` for thousands of small things,
`landmarks([[model, side, distance_from_edge, along, scale], ...])` for big props that come round,
`drifters(colour, amount, height, spread_x, velocity)` for fireflies, rain, snow or embers,
`add_light(light, energy)` for any light that should dim with the fuel gauge, `asset("models/x.glb")`.
You may override `_process(delta)` for animation (blinking signs, lightning), but call `super(delta)`.
Never put anything on the road itself (|x| < road_half), and keep the area right in front of the keys
dark enough that the cyan notes read. The player's notes are always cyan in every region.

## Props (`props.py`)

1 unit = 1 game unit, origin on the ground at the centre, Blender +Y is down the road. Lit, road-facing
sides go on Blender **-X**. A repeating prop is exactly one repeat long, and its spacing constant must
match the world script. Every region needs a `hood` model, the player's vehicle seen from the driver's
seat: copy `hood()` from `tools/themes/backroads/props.py`, keep its footprint (half-width 8, running
toward -Y about 9.6, top from 0 to about 0.95, lamps at the front corners), and change the styling.
Keep props low-poly (under about 1,500 triangles each) and flat-shaded.

## Textures (`textures.py`)

`from paintkit import *`, `set_out("game/assets/themes/<id>/textures")`. The sky is a 4096×2048
equirectangular panorama: horizon at half height, the centre column is straight down the road, and
anything you want in shot sits a little above the horizon (the camera looks slightly down). GIMP 3 hides
`gegl:linear-gradient` from scripts, so use `gradient()`. `Gimp.Drawable.threshold` works but warns.
Fonts come from macOS (`pick_font` takes a fallback list).

## Songs (`tools/song/songs/<song>.py`)

Copy `county_line.py`. Write **original** music only: no melodies, lyrics or titles from existing
songs, except public-domain pieces (Aurora Pass). `Song(id, title, theme, bpm, lead_patch)`,
`song.hit(t, instrument, midi, seconds, amp, pan)` for backing, `song.melody(bar, ["E4:1 G4:0.5 r:1", ...])`
for the lead (durations in beats), `song.section(name, bar)`, `song.write(bars)`.

- Lanes are the Q row, MIDI 60 (C4) to 79 (G5). Write melodies in C major or A minor so they stay on
  white keys, or pass `lane_shift` to transpose the chart only. The audio always plays what you wrote.
- Notes of 0.75 s or longer are holds. Aim for a quarter to a third of the notes as holds.
- Difficulty climbs along the map. County Line (region 1) is about 0.9 notes a second on Normal.
  Region 2 about 1.2 to 1.6, region 3 1.5 to 2, region 4 2 to 2.6, region 5 varies by piece. Never
  write two notes closer than 0.12 s.
- Songs run 75 to 120 seconds, with a 2 to 4 bar intro before the first melody note.
- Instruments in `tools/song/synths/core.scd`: pick, bass, synthbass, organ, piano, epiano, pad, arp,
  power, bell, kick, snare, brush, hat, shaker, crash, tom, and the leads steel, sawlead, drive, flute.
  Every instrument takes midi, sus, amp and pan.
- The perfect bot must get an S on both difficulties (`bot_song.gd` exits non-zero otherwise).

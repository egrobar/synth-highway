# Synth Highway (Godot)

The full-game build. The original single-file web trainer in `../index.html` is untouched.

A night drive in five regions, each matched to a genre, played on a QWERTY piano. Clear any song in a
region to open the next road. Every song has Easy and Normal, and you can load your own songs.

## Play

The music and sound effects are not in git (they are about 360 MB of generated WAV). After a fresh
clone, render them once; this needs SuperCollider, Blender and GIMP on the PATH:

```bash
tools/build_assets.sh
```

Then:

```bash
godot --path game          # or tools/godot.sh, which also serialises concurrent Godot runs
```

Title → the route → drive → results. The route is one screen: regions along the top (← →), the
region's songs below (↑ ↓), the selected song's details on the right, Tab for Easy or Normal, Enter to
drive. Everything is clickable too. Results offer Enter for the next song, Space to drive again, Esc
for the route. In a drive, Space or Esc pauses; resuming counts in three beats.

**Practice** (P on the route, or on the results screen after running out of gas): the song cannot
fail, plays at 100%, 85% or 70% speed with the pitch corrected, and is never saved. **Settings** (S on
the title or the route): music and effects volume, note speed, letters on notes, beat flashes and
camera movement, fullscreen, and the timing check. A player with no saved runs starts on Easy.

**Every song is played on the home row**: `A S D F G H J K L ;`. Fingers rest on A S D F and J K L ;,
and the index fingers reach for G and H, so your hands never move between songs. Each note's lane
follows the melody's shape, one scale step per lane. Easy uses only the eight resting keys; Normal
adds G and H only when a melody needs more than eight steps. Notes, lanes and keys are coloured by
the finger that plays them, mirrored across the hands: violet pinky, yellow ring, green middle, cyan
index (`scripts/key_map.gd`). Sharps stay orange.

## Load your own song

Press **L** on the map or a song list, pick an MP3, WAV, FLAC, OGG, AIFF or MIDI file, name it, choose
the region it belongs to, and wait for the progress bar. It then appears in that region's list, marked
YOUR SONG (X twice moves it to the Trash).

- **Audio:** Demucs separates the vocals, Basic Pitch transcribes them, and a pitch tracker checks
  every note. librosa finds the tempo, first beat and key, and the lanes are moved to C major / A minor
  so they sit on white keys. The audio is never changed: the band plays, and your vocal comes in only
  while you hit it. A song with no vocal uses the top line of the other instruments. Expect a minute or
  two per song on this Mac.
- **MIDI:** the track named vocal, melody or lead (otherwise the busiest high track) is the melody; the
  others are recorded by SuperCollider with the region's instruments.
- One-time setup: `tools/setup_pipeline.sh` builds `.venv-pipeline/` (Python 3.11, torch, Demucs,
  Basic Pitch, librosa). Imports live in the Godot user folder, under `songs/`.
- Check it: `.venv-pipeline/bin/python tools/importer/test_import.py <work dir>` imports a sung MP3 and
  a MIDI file with known notes, and scores the charts.

## How a run works

- **Clock** (`scripts/song_clock.gd`): song time is read from audio playback
  (`get_playback_position` + time since last mix − output latency − your calibration), never summed
  from frame times. Both stems start inside one `AudioServer.lock()`, so they begin in the same mix.
- **Input timing:** Godot gives key events no timestamp, so a press is timed by the frame that sees it.
  The project runs uncapped at up to 240 fps with vsync off to keep that error to about 4 ms.
- **Rules** (`scripts/judge.gd`): Perfect within 70 ms, Good within 160 ms. Notes of 0.75 s or longer
  are holds. Holding earns points continuously, releasing in the last 150 ms counts as complete, and
  letting go early keeps what you earned, costs some fuel and cuts the melody, but keeps your combo.
- **Fuel:** misses and wrong keys drain it, hits refill it. Low fuel dims and flickers the headlights,
  and empty ends the run. Mistakes on Easy cost about half the fuel. No seeking and no speed control in
  a scored run.
- **Feel:** each beat flares the glow, the road's edge lines and the hit line; the combo heats the
  world up (faster scenery, a slightly wider view); a miss jolts the camera; combos of 25, 50, 100...
  are called out. All of it is display only and switches off in Settings.
- **Results** show how early or late you typically press and the keys you slipped on most; out of
  gas, how far you got.
- **Difficulty:** Easy is generated from Normal by `tools/song/songlib.py`: at least a beat and a
  quarter between notes, keeping holds and on-beat notes first.

## Checks

```bash
tools/godot.sh --headless -s res://tests/test_judge.gd                                  # rules tests
tools/godot.sh --headless -s res://tests/bot_song.gd -- --song=county_line --difficulty=easy
tools/godot.sh --always-on-top -s res://tests/preview.gd -- --theme=backroads --song=county_line --at=30 --out=/abs/frame.png
tools/godot.sh --always-on-top -- --bot=perfect --muted --song=county_line              # real time, prints TIMING
```

Bots: `perfect`, `tapper` (hits every note but never holds), `sloppy`, `afk` (runs out of gas).
On macOS a game window must be `--always-on-top` for screenshots, or it renders black.

## Making assets and regions

Everything in `assets/` and `data/` is generated: `../tools/build_assets.sh [ids]` rebuilds it with
SuperCollider (music, ambience, effects), Blender (props) and GIMP (textures, logos). How a region is put
together, and how to add one, is in `../tools/themes/README.md`.

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

Title → route map (← → choose a region) → its songs (↑ ↓ song, ← → difficulty, Enter to drive) →
results. C on the title screen runs the timing check. In a drive, Space or Esc pauses; resuming counts
in three beats. Melodies use the Q row: `Q W E R T Y U I O P [ ]` are the white keys from C4 to G5,
with the sharps on the number row.

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
  and empty ends the run. The song's tempo never changes. No seeking and no speed control in a run.
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

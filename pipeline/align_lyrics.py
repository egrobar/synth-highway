"""Put the REAL lyrics on the timeline.

1. Whisper's word timestamps (the .lyrics.json sidecar) are fuzzy-matched to the
   real words with a sequence alignment -> anchors.
2. Runs of real words Whisper never heard (a skipped chorus, say) are forced-
   aligned to the vocal stem between the surrounding anchors with torchaudio's
   MMS_FA aligner; tiny gaps are interpolated.
3. Everything is written as MIDI lyric events ("/" starts a line, trailing space
   ends a word) into a copy of the note MIDI, plus a .lyrics.json sidecar.

Usage: python align_lyrics.py lyrics.txt whisper.lyrics.json vocals.wav in.mid out.mid [--no-fa]
"""
import argparse
import difflib
import json
import pathlib
import re

import numpy as np
import pretty_midi

ap = argparse.ArgumentParser()
ap.add_argument("lyrics"); ap.add_argument("whisper_json"); ap.add_argument("vocals")
ap.add_argument("midi_in"); ap.add_argument("midi_out")
ap.add_argument("--no-fa", action="store_true", help="interpolate gaps instead of forced alignment")
ap.add_argument("--min-fa-run", type=int, default=4)
args = ap.parse_args()


def norm_tokens(word):
    w = word.lower().replace("’", "'")
    return [p.strip("'") for p in re.split(r"[^a-z']+", w) if p.strip("'")]


# ---- real lyrics -> lines of display words, flattened to tokens
lines = []
for raw in pathlib.Path(args.lyrics).read_text(encoding="utf-8").splitlines():
    s = raw.strip()
    if not s or re.match(r"^\[.*\]$", s):
        continue
    lines.append(s.split())
real = []  # (token, line_idx, word_idx)
for li, words in enumerate(lines):
    for wi, w in enumerate(words):
        for tok in norm_tokens(w):
            real.append((tok, li, wi))

# ---- whisper words -> tokens with times
wh = []
for line in json.loads(pathlib.Path(args.whisper_json).read_text(encoding="utf-8")):
    for w in line:
        toks = norm_tokens(w["word"])
        for k, tok in enumerate(toks):  # split a multi-token word's time evenly
            a = w["start"] + (w["end"] - w["start"]) * k / len(toks)
            b = w["start"] + (w["end"] - w["start"]) * (k + 1) / len(toks)
            wh.append((tok, a, b))

# ---- sequence alignment (Needleman-Wunsch with fuzzy token similarity)
def sim(a, b):
    return 1.0 if a == b else difflib.SequenceMatcher(None, a, b).ratio()

N, M, GAP, MIN_SIM = len(real), len(wh), -0.4, 0.62
S = np.zeros((N + 1, M + 1)); S[:, 0] = np.arange(N + 1) * GAP; S[0, :] = np.arange(M + 1) * GAP
P = np.zeros((N + 1, M + 1), dtype=np.int8)
simcache = {}
for i in range(1, N + 1):
    ti = real[i - 1][0]
    for j in range(1, M + 1):
        key = (ti, wh[j - 1][0])
        r = simcache.get(key)
        if r is None:
            r = simcache[key] = sim(*key)
        m = S[i - 1, j - 1] + (r if r >= MIN_SIM else -1.0)
        u = S[i - 1, j] + GAP
        l = S[i, j - 1] + GAP
        if m >= u and m >= l:
            S[i, j], P[i, j] = m, 0
        elif u >= l:
            S[i, j], P[i, j] = u, 1
        else:
            S[i, j], P[i, j] = l, 2
match = [None] * N
i, j = N, M
while i > 0 and j > 0:
    if P[i, j] == 0:
        if sim(real[i - 1][0], wh[j - 1][0]) >= MIN_SIM:
            match[i - 1] = j - 1
        i -= 1; j -= 1
    elif P[i, j] == 1:
        i -= 1
    else:
        j -= 1
# keep anchors monotonic in time
last = -1.0
for i in range(N):
    if match[i] is not None:
        if wh[match[i]][1] < last - 0.05:
            match[i] = None
        else:
            last = wh[match[i]][1]
# a Whisper "word" spanning seconds is a segment-end artifact, not a word
for i in range(N):
    if match[i] is not None and wh[match[i]][2] - wh[match[i]][1] > 2.5:
        match[i] = None
# two anchors with more lyric tokens between them than anyone could sing: drop the weaker one
changed = True
while changed:
    changed = False
    idx = [i for i in range(N) if match[i] is not None]
    for a, b in zip(idx, idx[1:]):
        dt = wh[match[b]][1] - wh[match[a]][2]
        if b - a >= 6 and dt < (b - a) / 5.0:
            sa, sb = sim(real[a][0], wh[match[a]][0]), sim(real[b][0], wh[match[b]][0])
            victim = b if sb <= sa else a
            print(f"[align] dropping anchor '{real[victim][0]}' at {wh[match[victim]][1]:.1f}s ({b - a} tokens in {dt:.1f}s)")
            match[victim] = None; changed = True; break
anchored = sum(m is not None for m in match)
print(f"[align] {anchored}/{N} lyric tokens anchored to Whisper words ({M} heard)")

start = [None] * N; end = [None] * N
for i, m in enumerate(match):
    if m is not None:
        start[i], end[i] = wh[m][1], wh[m][2]

# ---- audio + forced aligner for the gaps
import torch, torchaudio  # noqa: E402
wave, sr = torchaudio.load(args.vocals)
wave = wave.mean(0, keepdim=True)
if sr != 16000:
    wave = torchaudio.functional.resample(wave, sr, 16000); sr = 16000
duration = wave.size(1) / sr
fa = None
if not args.no_fa:
    try:
        bundle = torchaudio.pipelines.MMS_FA
        fa_model = bundle.get_model(with_star=False).eval()
        tokenizer, aligner = bundle.get_tokenizer(), bundle.get_aligner()
        def fa(t0, t1, tokens):
            seg = wave[:, int(t0 * sr):int(t1 * sr)]
            with torch.inference_mode():
                emission, _ = fa_model(seg)
            clean = [re.sub(r"[^a-z]", "", t) or "a" for t in tokens]
            spans = aligner(emission[0], tokenizer(clean))
            ratio = seg.size(1) / emission.size(1)
            return [(t0 + s[0].start * ratio / sr, t0 + s[-1].end * ratio / sr) for s in spans]
        print("[fa] MMS_FA ready")
    except Exception as exc:
        print("[fa] unavailable, interpolating instead:", exc)
        fa = None

# ---- vocal-activity prior: where in a window is someone actually singing?
x = wave[0].numpy(); HOP = 160
nfr = len(x) // HOP
rms = np.sqrt((x[:nfr * HOP].reshape(nfr, HOP) ** 2).mean(1))
rms = np.convolve(rms, np.ones(15) / 15, mode="same")
act = np.clip(rms - np.percentile(rms, 25), 0, None)
ft = (np.arange(nfr) + 0.5) * HOP / sr

def energy_starts(t0, t1, n):
    """n word starts spread over [t0,t1] in proportion to vocal energy."""
    a, b = int(np.searchsorted(ft, t0)), int(np.searchsorted(ft, t1))
    w = act[a:b]
    if b - a < 2 or w.sum() <= 1e-9:
        return [t0 + (t1 - t0) * (k + 0.5) / n for k in range(n)]
    c = np.cumsum(w); c = c / c[-1]
    return [float(ft[a + min(b - a - 1, int(np.searchsorted(c, (k + 0.5) / n)))]) for k in range(n)]

i = 0; fa_runs = prior_runs = packed = 0
while i < N:
    if start[i] is not None:
        i += 1; continue
    k = i
    while k < N and start[k] is None:
        k += 1
    t0 = end[i - 1] if i > 0 else 0.0
    t1 = start[k] if k < N else duration
    run = list(range(i, k))
    # a few words at the head of the next anchor's line: pack them right before it
    if k < N and len(run) <= 3 and all(real[r][1] == real[k][1] for r in run):
        for n, r in enumerate(run):
            start[r] = max(t0, t1 - 0.32 * (len(run) - n)); end[r] = start[r] + 0.28
        packed += 1; i = k; continue
    # a few words at the tail of the previous anchor's line: pack them right after it
    if i > 0 and len(run) <= 3 and all(real[r][1] == real[i - 1][1] for r in run):
        for n, r in enumerate(run):
            start[r] = min(t1, t0 + 0.05 + 0.32 * n); end[r] = start[r] + 0.28
        packed += 1; i = k; continue
    prior = energy_starts(t0, t1, len(run))
    done = False
    if fa and len(run) >= args.min_fa_run and 1.0 <= t1 - t0 <= 90:
        try:
            times = fa(max(0.0, t0 - 0.15), min(duration, t1 + 0.15), [real[r][0] for r in run])
            dev = float(np.median(np.abs(np.array([a for a, _ in times]) - np.array(prior))))
            if dev <= 2.0:
                for r, (a, b) in zip(run, times):
                    start[r], end[r] = a, min(b, a + 1.5)
                fa_runs += 1; done = True
            else:
                print(f"[fa] run at {t0:.1f}-{t1:.1f}s rejected (median {dev:.1f}s off the energy prior)")
        except Exception as exc:
            print(f"[fa] run at {t0:.1f}-{t1:.1f}s failed ({exc})")
    if not done:
        for r, s in zip(run, prior):
            start[r] = s; end[r] = s + 0.3
        prior_runs += 1
    i = k
print(f"[gaps] forced-aligned {fa_runs} runs, energy-prior {prior_runs}, packed {packed}")

# ---- tokens -> display words -> MIDI
word_times = {}
for (tok, li, wi), s, e in zip(real, start, end):
    cur = word_times.get((li, wi))
    word_times[(li, wi)] = (s, e) if cur is None else (min(cur[0], s), max(cur[1], e))

pm = pretty_midi.PrettyMIDI(args.midi_in)
pm.lyrics = []
out_lines = []
for li, words in enumerate(lines):
    ws = []
    for wi, w in enumerate(words):
        s, e = word_times.get((li, wi), (None, None))
        if s is None:
            continue
        ws.append({"start": round(s, 2), "end": round(e, 2), "word": w})
        pm.lyrics.append(pretty_midi.Lyric(("/" if wi == 0 else "") + w + " ", float(s)))
    if ws:
        out_lines.append(ws)
pm.write(args.midi_out)
pathlib.Path(args.midi_out).with_suffix(".lyrics.json").write_text(json.dumps(out_lines, indent=1), encoding="utf-8")
print(f"[midi] {args.midi_out}: {len(pm.lyrics)} lyric events, {len(out_lines)} lines")
for ws in out_lines:
    print(f"  {ws[0]['start']:6.1f}-{ws[-1]['end']:6.1f}  " + " ".join(w['word'] for w in ws))

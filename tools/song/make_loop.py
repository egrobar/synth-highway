#!/usr/bin/env python3
"""Turns a rendered ambience into a seamless loop by crossfading its tail into its head.

Noise beds cannot loop on their own: the last sample and the first never match,
so a plain loop clicks. Equal-power crossfading the extra tail over the start
removes the seam. Input is 16-bit stereo WAV from tools/song/render.scd.

Usage: python3 make_loop.py in.wav out.wav [crossfade_seconds]
"""
import array
import math
import sys
import wave


def main() -> None:
    src, dst = sys.argv[1], sys.argv[2]
    xfade_s = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0
    with wave.open(src, "rb") as r:
        params = r.getparams()
        data = array.array("h", r.readframes(params.nframes))
    ch = params.nchannels
    frames = len(data) // ch
    xf = int(xfade_s * params.framerate)
    loop_len = frames - xf
    out = array.array("h", data[: loop_len * ch])
    for i in range(xf):
        p = i / xf
        fade_in, fade_out = math.sin(p * math.pi / 2), math.cos(p * math.pi / 2)
        for c in range(ch):
            head = data[i * ch + c]
            tail = data[(loop_len + i) * ch + c]
            out[i * ch + c] = max(-32768, min(32767, int(head * fade_in + tail * fade_out)))
    with wave.open(dst, "wb") as w:
        w.setparams(params)
        w.writeframes(out.tobytes())
    print(f"loop: {loop_len / params.framerate:.2f}s")


if __name__ == "__main__":
    main()

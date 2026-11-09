# Shared UI art: the game logo. Run like a region's textures.py.
import os
import sys

sys.path.insert(0, os.path.join(os.environ["SYNTH_ROOT"], "tools/gimp"))
from paintkit import *  # noqa: E402,F403

set_out("game/assets/textures")
wordmark("SYNTH HIGHWAY", "logo.png", ["Impact", "Avenir Next Condensed Heavy", "Helvetica Neue Condensed Black"],
         150, "rgb(0.93,0.97,1.0)", "rgb(0.2,0.75,1.0)")
print("TEXTURES DONE")

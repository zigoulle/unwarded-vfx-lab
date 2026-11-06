#!/bin/bash
# Turns the frames tools/capture_docs.tscn saved into docs/images/knobs-live.gif
# (ffmpeg, two passes: a palette, then the GIF at 15 fps, 800 px wide).
# Usage, from the repo root:  bash tools/make_gif.sh <the frames folder it printed>
set -e
frames="${1:?the gif_frames folder capture_docs printed}"
out="docs/images/knobs-live.gif"
filters="fps=15,scale=800:-1:flags=lanczos"
ffmpeg -y -loglevel error -framerate 15 -i "$frames/frame_%03d.png" -vf "$filters,palettegen=stats_mode=diff" /tmp/palette.png
ffmpeg -y -loglevel error -framerate 15 -i "$frames/frame_%03d.png" -i /tmp/palette.png \
  -lavfi "$filters [x]; [x][1:v] paletteuse=dither=bayer:bayer_scale=4" -loop 0 "$out"
echo "$out"

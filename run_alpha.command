#!/bin/bash
# ======================= Settings =======================
WATCH="assets"          # folder to watch
OUT="assets/output"     # where results are saved
INTERVAL=1              # seconds between folder checks
JOBS=4                  # images processed at the same time
SCALE=0.5               # 1 = full size, 0.5 = 50%, 0.25 = 25%
COMPRESSION=3           # PNG compression 0-9 (0 = fastest/biggest, 9 = slowest/smallest)
PRED=none               # none = fastest, mixed = smaller files but slower
USE_PNGQUANT=0          # 1 = lossy 256-color compression (much smaller), needs: brew install pngquant
QUALITY="65-85"         # pngquant quality range, min-max (0-100)
# ========================================================

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
cd "$(dirname "$0")"
mkdir -p "$OUT"
rm -f "$OUT"/.*.lock "$OUT"/.*_tmp*.png      # clean up leftovers from a previous run

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not found. Install it with: brew install ffmpeg"
  read -p "Press Enter to close..."; exit 1
fi
if [ "$USE_PNGQUANT" = 1 ] && ! command -v pngquant >/dev/null 2>&1; then
  echo "pngquant not found (brew install pngquant). Continuing without it."
  USE_PNGQUANT=0
fi

# Build the filter (merge alpha, then scale if needed)
if [ "$SCALE" = 1 ]; then
  SCALE_F=""
else
  SCALE_F=",scale=iw*${SCALE}:ih*${SCALE}:flags=lanczos"
fi
FILTER="[1:v]format=gray[a];[0:v][a]alphamerge${SCALE_F},format=rgba[out]"

trap 'echo; echo "Stopping... (finishing current jobs)"; wait; exit 0' INT

# A file is ready if it hasn't been modified for 2 seconds (no sleep needed)
settled() {
  local now m
  now=$(date +%s)
  m=$(stat -f%m "$1" 2>/dev/null) || return 1
  [ $((now - m)) -ge 2 ] && [ -s "$1" ]
}

process() {
  local name=$1 rgb=$2 matte=$3 out=$4
  local tmp="$OUT/.${name}_tmp.png"
  local lock="$OUT/.${name}.lock"
  local fail="$OUT/.${name}.failed"

  if ffmpeg -y -loglevel error -i "$rgb" -i "$matte" \
       -filter_complex "$FILTER" -map "[out]" -frames:v 1 \
       -compression_level "$COMPRESSION" -pred "$PRED" "$tmp"; then

    if [ "$USE_PNGQUANT" = 1 ]; then
      # If pngquant can't reach the quality target, the lossless version is kept
      pngquant --quality="$QUALITY" --speed 3 --force --output "$tmp.q.png" -- "$tmp" \
        && mv -f "$tmp.q.png" "$tmp"
      rm -f "$tmp.q.png"
    fi

    mv -f "$tmp" "$out"
    rm -f "$fail"
    echo "$(date '+%H:%M:%S')  ✅ $name  ($(du -h "$out" | cut -f1 | xargs))"
  else
    rm -f "$tmp"
    touch "$fail"
    echo "$(date '+%H:%M:%S')  ❌ $name failed (are both images the same size?)"
  fi
  rm -f "$lock"
}

echo "Watching '$WATCH'  |  scale=$SCALE  compression=$COMPRESSION  jobs=$JOBS  pngquant=$USE_PNGQUANT"
echo "Press Ctrl+C to stop."

while true; do
  for rgb in "$WATCH"/*.png; do
    [ -e "$rgb" ] || continue
    name=$(basename "$rgb" .png)
    case "$name" in *_alpha) continue ;; esac

    matte="$WATCH/${name}_alpha.png"
    out="$OUT/${name}.png"
    fail="$OUT/.${name}.failed"

    [ -f "$matte" ] || continue                                   # matte not there yet
    [ -f "$OUT/.${name}.lock" ] && continue                       # already being processed
    [ -f "$out" ]  && [ "$out"  -nt "$rgb" ] && [ "$out"  -nt "$matte" ] && continue   # up to date
    [ -f "$fail" ] && [ "$fail" -nt "$rgb" ] && [ "$fail" -nt "$matte" ] && continue   # failed, files unchanged
    settled "$rgb" && settled "$matte" || continue                # still copying

    # Limit how many run at the same time
    while [ "$(jobs -rp | wc -l | tr -d ' ')" -ge "$JOBS" ]; do sleep 0.2; done

    touch "$OUT/.${name}.lock"
    echo "$(date '+%H:%M:%S')  ⏳ $name ..."
    process "$name" "$rgb" "$matte" "$out" &
  done
  sleep "$INTERVAL"
done
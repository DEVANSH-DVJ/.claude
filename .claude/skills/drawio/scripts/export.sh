#!/bin/bash
# Headless draw.io export, run inside the container via exec.sh.
# Usage: export.sh <in.drawio> <out.png or out.pdf> [scale] [page]
# Format from the extension (.pdf, else png); page is 1-based; scale is png only.
set -euo pipefail

IN=${1:?usage: export.sh <in.drawio> <out.png or out.pdf> [scale] [page]}
OUT=${2:?usage: export.sh <in.drawio> <out.png or out.pdf> [scale] [page]}
SCALE=${3:-3}
PAGE=${4:-1}
DEADLINE=120
XPID=

# Reap Xvfb on every exit path.
cleanup() {
  if [ -n "$XPID" ]; then
    kill "$XPID" 2>/dev/null || true
    wait "$XPID" 2>/dev/null || true
  fi
}
trap cleanup EXIT
fail() {
  echo "drawio-export: $1" >&2
  exit 1
}

# First display with neither socket nor lock.
for n in $(seq 90 119); do
  if [ ! -e "/tmp/.X11-unix/X$n" ] && [ ! -e "/tmp/.X$n-lock" ]; then
    DISP=$n
    break
  fi
done
[ -n "${DISP:-}" ] || fail "no free display in :90-:119"

Xvfb ":$DISP" -screen 0 1920x1080x24 -nolisten tcp >/dev/null 2>&1 &
XPID=$!

# Xvfb is up once its socket appears; 10 s cap.
for _ in $(seq 1 200); do
  [ -S "/tmp/.X11-unix/X$DISP" ] && break
  sleep 0.05
done
[ -S "/tmp/.X11-unix/X$DISP" ] || fail "Xvfb :$DISP did not start"

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

# Electron runs against this display and no session bus.
export DISPLAY=":$DISP"
export DBUS_SESSION_BUS_ADDRESS=/dev/null

# PDF is vector and cropped to the drawing; PNG is transparent and scaled.
case "${OUT##*.}" in
  pdf) FLAGS=(-f pdf --crop) ;;
  *) FLAGS=(-f png -t -s "$SCALE") ;;
esac

timeout -k 5 "$DEADLINE" drawio --no-sandbox --disable-gpu --disable-dev-shm-usage \
  -x "${FLAGS[@]}" -p "$PAGE" -e -b 0 -o "$OUT" "$IN" >/dev/null 2>&1 ||
  fail "$IN: export failed or exceeded ${DEADLINE}s"
[ -s "$OUT" ] || fail "$IN: no output written"

if [ "${OUT##*.}" = pdf ]; then
  # Normalize through poppler if present; raw exports can overflow pdfTeX.
  if command -v pdftocairo >/dev/null; then
    pdftocairo -pdf "$OUT" "$OUT.norm" && mv "$OUT.norm" "$OUT" || fail "$OUT: normalize failed"
  fi
  echo "drawio-export: $OUT (page $PAGE)"
  exit 0
fi

# Pixel size straight from the PNG IHDR.
SIZE=$(python -c 'import struct,sys;print("%dx%d"%struct.unpack(">II",open(sys.argv[1],"rb").read(24)[16:]))' "$OUT")
echo "drawio-export: $OUT $SIZE"

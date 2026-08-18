#!/bin/sh
set -eu

umask 077
PORT="${PORT:-8188}"

case "$PORT" in
  ''|*[!0-9]*)
    echo "ERROR: PORT must be a numeric TCP port between 1 and 65535." >&2
    exit 64
    ;;
esac

if ! python3 -c 'import sys; port = int(sys.argv[1]); sys.exit(0 if 1 <= port <= 65535 else 1)' "$PORT"; then
  echo "ERROR: PORT must be a numeric TCP port between 1 and 65535." >&2
  exit 64
fi

if [ -z "${REPLICATE_API_TOKEN:-}" ]; then
  echo "ERROR: REPLICATE_API_TOKEN is not set." >&2
  echo "Create it as a TrueFoundry secret and inject it as the REPLICATE_API_TOKEN environment variable." >&2
  exit 78
fi

mkdir -p /data/input /data/output /data/temp /data/user/default/workflows

# Seed the default workflow once without overwriting user edits on later restarts.
if [ ! -f /data/user/default/workflows/WNS_Replicate_Seedance25.json ]; then
  cp /opt/wns-bundle/workflows/WNS_Replicate_Seedance25.json \
    /data/user/default/workflows/WNS_Replicate_Seedance25.json
fi

cd /opt/ComfyUI
exec python main.py \
  --listen 0.0.0.0 \
  --port "$PORT" \
  --cpu \
  --disable-auto-launch \
  --input-directory /data/input \
  --output-directory /data/output \
  --temp-directory /data/temp \
  --user-directory /data/user \
  --database-url sqlite:////data/user/comfyui.db

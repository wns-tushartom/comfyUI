#!/bin/sh
set -eu

umask 077
mkdir -p /data/input /data/output /data/temp /data/user /data/models /data/custom_nodes

cd /opt/ComfyUI
exec python main.py \
  --listen 0.0.0.0 \
  --port 8188 \
  --cpu \
  --disable-auto-launch \
  --base-directory /data \
  --database-url sqlite:////data/user/comfyui.db

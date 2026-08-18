FROM python:3.11-slim-bookworm

ARG COMFYUI_REF=e5a38e3f7b91619ff295ffbbeddff35d8e381677
ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl ffmpeg git libgl1 libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git init ComfyUI \
    && cd ComfyUI \
    && git remote add origin https://github.com/Comfy-Org/ComfyUI.git \
    && git fetch --depth 1 origin "${COMFYUI_REF}" \
    && git checkout --detach FETCH_HEAD

WORKDIR /opt/ComfyUI
RUN python -m pip install --upgrade pip setuptools wheel \
    && python -m pip install --index-url https://download.pytorch.org/whl/cpu torch torchvision torchaudio \
    && python -m pip install -r requirements.txt

COPY start-comfyui.sh /usr/local/bin/start-comfyui
RUN chmod 0755 /usr/local/bin/start-comfyui && mkdir -p /data

EXPOSE 8188
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
  CMD curl -fsS http://127.0.0.1:8188/system_stats >/dev/null || exit 1

CMD ["/usr/local/bin/start-comfyui"]

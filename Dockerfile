FROM python:3.11-slim-bookworm

# Pin the exact ComfyUI revision verified with this workflow.
ARG COMFYUI_REF=7c4d95d1bc2ef178937d203aa81070db0b172a92
ARG TORCH_VERSION=2.9.1+cpu
ARG TORCHVISION_VERSION=0.24.1+cpu
ARG TORCHAUDIO_VERSION=2.9.1+cpu
ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PORT=8188

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl ffmpeg git libgl1 libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt
RUN git init ComfyUI \
    && cd ComfyUI \
    && git remote add origin https://github.com/Comfy-Org/ComfyUI.git \
    && git fetch --depth 1 origin "${COMFYUI_REF}" \
    && git checkout --detach FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "${COMFYUI_REF}"

WORKDIR /opt/ComfyUI
RUN python -m pip install --upgrade pip setuptools wheel \
    && python -m pip install --index-url https://download.pytorch.org/whl/cpu \
      "torch==${TORCH_VERSION}" \
      "torchvision==${TORCHVISION_VERSION}" \
      "torchaudio==${TORCHAUDIO_VERSION}" \
    && python -m pip install -r requirements.txt

COPY custom_nodes/wns_replicate_video/requirements.txt /tmp/wns-replicate-requirements.txt
RUN python -m pip install -r /tmp/wns-replicate-requirements.txt \
    && rm /tmp/wns-replicate-requirements.txt

COPY custom_nodes/wns_replicate_video /opt/ComfyUI/custom_nodes/wns_replicate_video
COPY workflows /opt/wns-bundle/workflows
COPY start-comfyui.sh /usr/local/bin/start-comfyui
RUN chmod 0755 /usr/local/bin/start-comfyui \
    && mkdir -p /data /opt/wns-bundle

EXPOSE 8188
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
  CMD curl -fsS "http://127.0.0.1:${PORT:-8188}/system_stats" >/dev/null || exit 1

CMD ["/usr/local/bin/start-comfyui"]

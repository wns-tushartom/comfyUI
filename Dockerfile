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
# Keep the default workflow inside the image so builds do not depend on a
# separately checked-in workflows/ directory in the TrueFoundry source context.
RUN python -c "import base64, pathlib; p=pathlib.Path('/opt/wns-bundle/workflows/WNS_Replicate_Seedance25.json'); p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(base64.b64decode('ewogICJsYXN0X25vZGVfaWQiOiAyLAogICJsYXN0X2xpbmtfaWQiOiAxLAogICJub2RlcyI6IFsKICAgIHsKICAgICAgImlkIjogMSwKICAgICAgInR5cGUiOiAiV05TUmVwbGljYXRlUHJvbXB0IiwKICAgICAgInBvcyI6IFsxMjAsIDE4MF0sCiAgICAgICJzaXplIjogWzQzMCwgMjQwXSwKICAgICAgImZsYWdzIjoge30sCiAgICAgICJvcmRlciI6IDAsCiAgICAgICJtb2RlIjogMCwKICAgICAgIm91dHB1dHMiOiBbCiAgICAgICAgewogICAgICAgICAgIm5hbWUiOiAicHJvbXB0IiwKICAgICAgICAgICJ0eXBlIjogIlNUUklORyIsCiAgICAgICAgICAibGlua3MiOiBbMV0sCiAgICAgICAgICAic2hhcGUiOiAzLAogICAgICAgICAgInNsb3RfaW5kZXgiOiAwCiAgICAgICAgfQogICAgICBdLAogICAgICAicHJvcGVydGllcyI6IHsKICAgICAgICAiTm9kZSBuYW1lIGZvciBTJlIiOiAiV05TUmVwbGljYXRlUHJvbXB0IgogICAgICB9LAogICAgICAid2lkZ2V0c192YWx1ZXMiOiBbCiAgICAgICAgIkEgY2luZW1hdGljIGNsb3NlLXVwIG9mIGEgZnV0dXJpc3RpYyBnbGFzcyBjaXR5IGF0IHN1bnJpc2UsIHNvZnQgdm9sdW1ldHJpYyBsaWdodCwgc2xvdyBjYW1lcmEgcHVzaC1pbiwgcmVhbGlzdGljIHJlZmxlY3Rpb25zIgogICAgICBdCiAgICB9LAogICAgewogICAgICAiaWQiOiAyLAogICAgICAidHlwZSI6ICJXTlNSZXBsaWNhdGVTZWVkYW5jZTI1IiwKICAgICAgInBvcyI6IFs2NTAsIDE4MF0sCiAgICAgICJzaXplIjogWzQzMCwgMzkwXSwKICAgICAgImZsYWdzIjoge30sCiAgICAgICJvcmRlciI6IDEsCiAgICAgICJtb2RlIjogMCwKICAgICAgImlucHV0cyI6IFsKICAgICAgICB7CiAgICAgICAgICAibmFtZSI6ICJwcm9tcHQiLAogICAgICAgICAgInR5cGUiOiAiU1RSSU5HIiwKICAgICAgICAgICJsaW5rIjogMQogICAgICAgIH0KICAgICAgXSwKICAgICAgIm91dHB1dHMiOiBbCiAgICAgICAgewogICAgICAgICAgIm5hbWUiOiAic2F2ZWRfdmlkZW9fcGF0aCIsCiAgICAgICAgICAidHlwZSI6ICJTVFJJTkciLAogICAgICAgICAgImxpbmtzIjogbnVsbCwKICAgICAgICAgICJzaGFwZSI6IDMsCiAgICAgICAgICAic2xvdF9pbmRleCI6IDAKICAgICAgICB9CiAgICAgIF0sCiAgICAgICJwcm9wZXJ0aWVzIjogewogICAgICAgICJOb2RlIG5hbWUgZm9yIFMmUiI6ICJXTlNSZXBsaWNhdGVTZWVkYW5jZTI1IgogICAgICB9LAogICAgICAid2lkZ2V0c192YWx1ZXMiOiBbCiAgICAgICAgNSwKICAgICAgICAiNzIwcCIsCiAgICAgICAgIjE2OjkiLAogICAgICAgIHRydWUsCiAgICAgICAgZmFsc2UsCiAgICAgICAgLTEsCiAgICAgICAgIldOU19TZWVkYW5jZTI1IgogICAgICBdCiAgICB9CiAgXSwKICAibGlua3MiOiBbCiAgICBbMSwgMSwgMCwgMiwgMCwgIlNUUklORyJdCiAgXSwKICAiZ3JvdXBzIjogWwogICAgewogICAgICAiaWQiOiAxLAogICAgICAidGl0bGUiOiAiV05TIFJlcGxpY2F0ZSDCtyBTZWVkYW5jZSAyLjUgVGV4dC10by1WaWRlbyIsCiAgICAgICJib3VuZGluZyI6IFs3MCwgOTAsIDEwNjAsIDU0MF0sCiAgICAgICJjb2xvciI6ICIjM2Y3ODllIiwKICAgICAgImZvbnRfc2l6ZSI6IDI0LAogICAgICAiZmxhZ3MiOiB7fQogICAgfQogIF0sCiAgImNvbmZpZyI6IHt9LAogICJleHRyYSI6IHsKICAgICJkcyI6IHsKICAgICAgInNjYWxlIjogMSwKICAgICAgIm9mZnNldCI6IFswLCAwXQogICAgfSwKICAgICJmcm9udGVuZFZlcnNpb24iOiAiMS40My4xOCIKICB9LAogICJ2ZXJzaW9uIjogMC40Cn0K'))"
COPY start-comfyui.sh /usr/local/bin/start-comfyui
RUN chmod 0755 /usr/local/bin/start-comfyui \
    && mkdir -p /data /opt/wns-bundle

EXPOSE 8188
HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
  CMD curl -fsS "http://127.0.0.1:${PORT:-8188}/system_stats" >/dev/null || exit 1

CMD ["/usr/local/bin/start-comfyui"]

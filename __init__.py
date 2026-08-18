from __future__ import annotations

import base64
import binascii
import os
import re
import urllib.parse
import uuid
from pathlib import Path
from typing import Any

import folder_paths
import httpx
import replicate

_MODEL = "bytedance/seedance-2.5"
_MAX_DOWNLOAD_BYTES = 1_000_000_000
_SAFE_PREFIX = re.compile(r"[^A-Za-z0-9_-]+")
_ALLOWED_DOWNLOAD_HOSTS = ("replicate.delivery",)


class WNSReplicatePrompt:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "prompt": (
                    "STRING",
                    {
                        "multiline": True,
                        "default": (
                            "A cinematic close-up of a futuristic glass city at sunrise, "
                            "soft volumetric light, slow camera push-in, realistic reflections"
                        ),
                    },
                )
            }
        }

    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("prompt",)
    FUNCTION = "emit"
    CATEGORY = "WNS/Replicate"

    def emit(self, prompt: str):
        if not prompt.strip():
            raise ValueError("Prompt must not be blank.")
        if len(prompt) > 2_000:
            raise ValueError("Prompt must be at most 2,000 characters for Seedance 2.5.")
        return (prompt,)


class WNSReplicateSeedance25:
    @classmethod
    def INPUT_TYPES(cls):
        return {
            "required": {
                "prompt": ("STRING", {"forceInput": True}),
                "duration": ("INT", {"default": 5, "min": 5, "max": 30, "step": 1}),
                "resolution": (["720p", "480p"], {"default": "720p"}),
                "aspect_ratio": (
                    ["16:9", "9:16", "1:1", "4:3", "3:4", "21:9", "adaptive"],
                    {"default": "16:9"},
                ),
                "generate_audio": ("BOOLEAN", {"default": True}),
                "watermark": ("BOOLEAN", {"default": False}),
                "seed": (
                    "INT",
                    {
                        "default": -1,
                        "min": -1,
                        "max": 2_147_483_647,
                        "step": 1,
                        "tooltip": "-1 lets the model choose a random seed.",
                    },
                ),
                "filename_prefix": ("STRING", {"default": "WNS_Seedance25"}),
            }
        }

    RETURN_TYPES = ("STRING",)
    RETURN_NAMES = ("saved_video_path",)
    FUNCTION = "generate"
    CATEGORY = "WNS/Replicate"
    OUTPUT_NODE = True

    @classmethod
    def IS_CHANGED(cls, **_kwargs):
        return float("NaN")

    def generate(
        self,
        prompt: str,
        duration: int,
        resolution: str,
        aspect_ratio: str,
        generate_audio: bool,
        watermark: bool,
        seed: int,
        filename_prefix: str,
    ):
        if not os.environ.get("REPLICATE_API_TOKEN"):
            raise RuntimeError(
                "REPLICATE_API_TOKEN is not set. Set it in the environment before starting ComfyUI; "
                "never paste the token into the workflow."
            )
        if not prompt.strip():
            raise ValueError("Prompt must not be blank.")
        if len(prompt) > 2_000:
            raise ValueError("Prompt must be at most 2,000 characters for Seedance 2.5.")

        request_input: dict[str, Any] = {
            "prompt": prompt,
            "duration": duration,
            "resolution": resolution,
            "aspect_ratio": aspect_ratio,
            "generate_audio": generate_audio,
            "watermark": watermark,
            "output_format": "mp4",
        }
        if seed >= 0:
            request_input["seed"] = seed

        output = replicate.run(_MODEL, input=request_input)
        video_bytes = self._read_output(output)
        if not video_bytes:
            raise RuntimeError("Replicate returned an empty video.")

        output_dir = Path(folder_paths.get_output_directory()) / "wns_replicate"
        output_dir.mkdir(parents=True, exist_ok=True)
        prefix = _SAFE_PREFIX.sub("_", filename_prefix).strip("_")[:80] or "WNS_Seedance25"
        filename = f"{prefix}_{uuid.uuid4().hex[:10]}.mp4"
        destination = output_dir / filename
        part = destination.with_suffix(".mp4.part")
        try:
            with part.open("wb") as handle:
                handle.write(video_bytes)
                handle.flush()
                os.fsync(handle.fileno())
            part.replace(destination)
        finally:
            part.unlink(missing_ok=True)

        preview = {
            "filename": filename,
            "subfolder": "wns_replicate",
            "type": "output",
            "format": "video/mp4",
        }
        return {
            "ui": {"images": [preview], "animated": (True,)},
            "result": (str(destination),),
        }

    @staticmethod
    def _read_output(output: Any) -> bytes:
        url_value = getattr(output, "url", None)
        url = url_value() if callable(url_value) else url_value
        if not url and isinstance(output, str):
            url = output

        if isinstance(url, str):
            if url.startswith("data:"):
                return WNSReplicateSeedance25._decode_inline_output(url)
            return WNSReplicateSeedance25._download_output(url)

        if isinstance(output, bytes):
            data = output
        elif hasattr(output, "read"):
            try:
                data = output.read(_MAX_DOWNLOAD_BYTES + 1)
            except TypeError:
                data = output.read()
        else:
            raise TypeError(f"Unsupported Replicate output type: {type(output).__name__}")

        if not isinstance(data, bytes):
            raise TypeError("Replicate output stream did not return bytes.")
        if len(data) > _MAX_DOWNLOAD_BYTES:
            raise RuntimeError("Replicate video exceeds the 1 GB safety limit.")
        return data

    @staticmethod
    def _decode_inline_output(url: str) -> bytes:
        try:
            header, encoded = url.split(",", 1)
        except ValueError as exc:
            raise RuntimeError("Replicate returned a malformed inline video.") from exc
        if ";base64" not in header.lower():
            raise RuntimeError("Replicate returned an unsupported inline video encoding.")
        max_encoded = ((_MAX_DOWNLOAD_BYTES + 2) // 3) * 4
        if len(encoded) > max_encoded:
            raise RuntimeError("Replicate video exceeds the 1 GB safety limit.")
        try:
            data = base64.b64decode(encoded, validate=True)
        except (binascii.Error, ValueError) as exc:
            raise RuntimeError("Replicate returned invalid inline video data.") from exc
        if len(data) > _MAX_DOWNLOAD_BYTES:
            raise RuntimeError("Replicate video exceeds the 1 GB safety limit.")
        return data

    @staticmethod
    def _download_output(url: str) -> bytes:
        headers = {"User-Agent": "WNS-ComfyUI-Replicate/1.0"}
        current_url = url
        with httpx.Client(follow_redirects=False, timeout=120.0, headers=headers) as client:
            for _redirect in range(6):
                parsed = urllib.parse.urlparse(current_url)
                host = (parsed.hostname or "").lower()
                if parsed.scheme != "https" or not any(
                    host == allowed or host.endswith(f".{allowed}")
                    for allowed in _ALLOWED_DOWNLOAD_HOSTS
                ):
                    raise RuntimeError("Replicate returned an untrusted output URL.")

                with client.stream("GET", current_url) as response:
                    if response.is_redirect:
                        location = response.headers.get("Location")
                        if not location:
                            raise RuntimeError("Replicate returned a redirect without a destination.")
                        current_url = urllib.parse.urljoin(current_url, location)
                        continue

                    response.raise_for_status()
                    declared = response.headers.get("Content-Length")
                    if declared and int(declared) > _MAX_DOWNLOAD_BYTES:
                        raise RuntimeError("Replicate video exceeds the 1 GB safety limit.")

                    data = bytearray()
                    for chunk in response.iter_bytes():
                        data.extend(chunk)
                        if len(data) > _MAX_DOWNLOAD_BYTES:
                            raise RuntimeError("Replicate video exceeds the 1 GB safety limit.")
                    return bytes(data)

        raise RuntimeError("Replicate output exceeded the redirect limit.")


NODE_CLASS_MAPPINGS = {
    "WNSReplicatePrompt": WNSReplicatePrompt,
    "WNSReplicateSeedance25": WNSReplicateSeedance25,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "WNSReplicatePrompt": "WNS Replicate Prompt",
    "WNSReplicateSeedance25": "WNS Replicate Seedance 2.5",
}

__all__ = ["NODE_CLASS_MAPPINGS", "NODE_DISPLAY_NAME_MAPPINGS"]

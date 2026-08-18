# WNS ComfyUI Replicate Controller on TrueFoundry

This repository builds a CPU-only ComfyUI controller for TrueFoundry and installs a dedicated text-to-video workflow backed by Replicate's official `bytedance/seedance-2.5` model. The container performs orchestration and downloads the generated MP4; video inference runs on Replicate.

No Comfy credits or Comfy Partner Nodes are used. The Replicate token is injected at runtime and never stored in the image, repository, node widgets, or workflow JSON.

## Included workflow

The image installs these custom nodes:

- `WNS Replicate Prompt`
- `WNS Replicate Seedance 2.5`

It seeds this workflow on first startup:

```text
/data/user/default/workflows/WNS_Replicate_Seedance25.json
```

Generated videos are stored on the persistent volume under:

```text
/data/output/wns_replicate/
```

## Required TrueFoundry secret

Create a TrueFoundry secret containing your Replicate token from:

```text
https://replicate.com/account/api-tokens
```

Inject it into the service as the environment variable:

```text
REPLICATE_API_TOKEN
```

Use a TrueFoundry secret reference rather than pasting the raw token into the deployment specification. A secret reference has a form similar to:

```text
tfy-secret://user:<secret-group>:<secret-name>
```

The service intentionally exits during startup if `REPLICATE_API_TOKEN` is absent. Never commit the token, put it in the Dockerfile, add it to workflow JSON, or expose it as a node widget.

## TrueFoundry deployment settings

Use **Git repository + Dockerfile**.

| Setting | Value |
|---|---|
| Deployment type | Service |
| Build context | `./` |
| Dockerfile | `./Dockerfile` |
| Replicas | Exactly `1` |
| GPU | None |
| CPU request / limit | `1` / `2` |
| Memory request / limit | `4 GB` / `8 GB` |
| Ephemeral storage | At least `5 GB`; `10 GB` preferred |
| Persistent volume | `20-50 GB` mounted at `/data` |
| Container port | `8188` |
| Environment variable | `PORT=8188` |
| Secret environment variable | `REPLICATE_API_TOKEN=<TrueFoundry secret reference>` |
| Readiness path | `/system_stats` on port `8188` |
| Liveness path | `/system_stats` on port `8188` |
| Autoscaling | Disabled |
| Endpoint | HTTPS at `/` |
| Endpoint authentication | TrueFoundry login preferred |

Do not run multiple replicas against the same `/data/user/comfyui.db`. ComfyUI uses SQLite here, so the service deliberately remains single-replica.

## Deploy an update from GitHub

1. Replace the repository contents with this complete bundle, preserving the `custom_nodes/` and `workflows/` directories.
2. Commit and push all files.
3. In TrueFoundry, deploy a new service version from that Git commit.
4. Confirm the `/data` persistent volume remains attached.
5. Confirm `REPLICATE_API_TOKEN` points to the TrueFoundry secret.
6. Confirm the service port and probes use `8188` and `/system_stats`.
7. Wait for the deployment to become healthy.

## Use the workflow

1. Open the authenticated TrueFoundry HTTPS endpoint.
2. In ComfyUI, load `WNS_Replicate_Seedance25` from the workflow menu. If the menu does not refresh immediately, reload the page once.
3. Enter the prompt.
4. Choose duration, resolution, aspect ratio, audio, watermark, and seed settings.
5. Queue the workflow.
6. Retrieve the resulting MP4 from ComfyUI history/output or `/data/output/wns_replicate/`.

A live queue action is billable through Replicate. Start with a five-second test.

## Startup behavior

`start-comfyui.sh`:

- validates `PORT` and requires `REPLICATE_API_TOKEN`;
- keeps mutable ComfyUI input, output, temporary files, user workflows, and SQLite state under `/data`;
- loads the reviewed `wns_replicate_video` custom node from the immutable container image rather than executing persistent-volume custom code;
- seeds the workflow only when it does not already exist, preserving later user edits;
- starts ComfyUI with `--cpu`, so it does not attempt CUDA initialization on the controller;
- binds to `0.0.0.0:$PORT` for TrueFoundry routing.

## Local smoke test

Build:

```bash
docker build -t wns-comfyui-replicate:verified .
```

Run with a token supplied only at runtime:

```bash
docker run --rm -d \
  --name wns-comfyui-replicate-test \
  -p 127.0.0.1:18188:8188 \
  -e REPLICATE_API_TOKEN \
  -e PORT=8188 \
  -v wns-comfyui-replicate-data:/data \
  wns-comfyui-replicate:verified
```

Health check:

```bash
curl -fsS http://127.0.0.1:18188/system_stats
```

Stop:

```bash
docker stop wns-comfyui-replicate-test
```

The local smoke proves startup and node registration. Do not queue a workflow unless you intend to make a paid Replicate request.

## Version pinning

The Dockerfile pins the exact ComfyUI Git revision, CPU PyTorch packages, and Replicate client version used for validation. Upgrade those pins deliberately, rebuild, and verify `/system_stats`, custom-node registration, workflow loading, and one explicitly approved low-cost generation before deploying the new version.

# ComfyUI CPU Controller on TrueFoundry

This image runs the official ComfyUI source as a CPU-only workflow controller. Heavy image/video inference is expected to run through Comfy Partner/API Nodes.

## TrueFoundry deployment values

- Deployment type: Service
- Service name: `comfyui-controller`
- Source: Git repository + Dockerfile, or Code from Laptop + Dockerfile
- Docker build context: `./`
- Dockerfile: `./Dockerfile`
- Replicas: exactly `1`
- GPU: none
- CPU request/limit: `1` / `2`
- Memory request/limit: `4000 MB` / `8000 MB`
- Ephemeral storage request/limit: `5000 MB` / `10000 MB`
- Persistent volume: `20–50 GB`, mounted at `/data`
- Port: `8188`
- Protocol/application protocol: HTTP
- Expose: enabled
- Endpoint: wildcard subdomain preferred, path `/`
- Authentication: Login with TrueFoundry preferred; Basic Auth is the fallback
- Readiness and liveness path: `/system_stats` on port `8188`
- Autoscaling: off; keep exactly one replica

Never run multiple replicas against the same `/data/user/comfyui.db`.

## Comfy Partner/API Node login

1. Create a Comfy API key at https://platform.comfy.org/login.
2. Open the deployed HTTPS ComfyUI endpoint.
3. Go to Settings → User → Comfy API Key.
4. Paste the key and save.
5. Add prepaid credits under Settings → Credits.
6. Start with the cheapest API-node smoke test. No local checkpoint download is needed.

TrueFoundry endpoint authentication protects the web application. The Comfy API key authorizes and bills Partner/API Node calls. They are separate credentials.

For scripted `POST /prompt` calls containing Partner Nodes, include the key in the top-level payload:

```json
{
  "prompt": {"...": "API-format workflow"},
  "extra_data": {
    "api_key_comfy_org": "comfyui-..."
  }
}
```

Do not put the Comfy key in the Dockerfile, Git repository, or saved workflow JSON.

## Local verification

```bash
docker build -t comfyui-tfy-cpu:verified .
```

```bash
docker run --rm -d --name comfyui-tfy-test -p 127.0.0.1:18188:8188 -v comfyui-tfy-test-data:/data comfyui-tfy-cpu:verified
```

```bash
curl -fsS http://127.0.0.1:18188/system_stats
```

Stop the local test with:

```bash
docker stop comfyui-tfy-test
```

## Upgrade discipline

The Dockerfile pins the ComfyUI Git revision. To upgrade, replace `COMFYUI_REF` with a reviewed commit, rebuild, verify `/system_stats` and one low-cost Partner Node workflow, then deploy a new TrueFoundry version. Do not track an unpinned moving branch in production.

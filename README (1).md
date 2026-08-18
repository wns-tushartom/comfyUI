# WNS Replicate Video nodes

ComfyUI nodes for text-to-video generation through Replicate's official `bytedance/seedance-2.5` model.

`REPLICATE_API_TOKEN` is read only from the server process environment. It is not a node widget and is not serialized into workflow JSON.

Generated videos are saved under the active ComfyUI output directory in `wns_replicate/`. In this TrueFoundry image that resolves to `/data/output/wns_replicate/`.

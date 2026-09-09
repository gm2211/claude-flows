# Local runtime

From the plugin directory:

```sh
docker compose -f runtime/compose.yaml up -d --build
```

Editor: http://127.0.0.1:3100 . MCP Streamable HTTP: http://127.0.0.1:3100/mcp . Health: `/health`.
The plugin's `.mcp.json` registers that endpoint in compatible plugin hosts. A host may need a reload before newly installed MCP tools become available. For other agents register that URL with their HTTP MCP client.

One container contains the official Excalidraw React editor (from excalidraw/excalidraw), the pinned excalidraw/excalidraw-mcp server, and a small shared-checkpoint HTTP adapter. The editor package resolves through upstream's frozen pnpm lockfile. This is an embedded Excalidraw editor, not the full excalidraw.com web application. The browser editor bundles its JS and fonts locally. The unmodified upstream MCP App widget still loads dependencies from esm.sh; the local editor remains the local rendering route.

The server binds only to host loopback through Compose. A named volume preserves scenes across container restarts. Do not use `down -v` unless intentionally deleting saved diagrams. The local scene API has no authentication; do not expose its port publicly.

- `GET /api/scenes`: checkpoint names.
- `GET /api/scenes/ID`: scene/checkpoint JSON.
- `PUT /api/scenes/ID`: `{elements: [...], appState: {...}, files: {...}}`, up to 5 MB.
- `/?scene=ID`: load the shared checkpoint in the editor.
- Save persists browser changes; Reload fetches agent changes. Concurrent writers should coordinate; last save wins.

Use `scripts/scene.py put NAME source.excalidraw`, `get NAME output.excalidraw`, or `mcp TOOL arguments.json` when an MCP tool is not callable in the current session. Pass `--url` before the subcommand to override the default origin. PNG and SVG come from the editor's export buttons, not an approximate renderer.

Upstream references: https://github.com/excalidraw/excalidraw and https://github.com/excalidraw/excalidraw-mcp . MCP source is pinned in `runtime/Dockerfile`; update intentionally and rebuild/smoke-test. Upstream's `export_to_excalidraw` sends scene data to json.excalidraw.com; it is not used for local exports.

## Verification

After starting the container, run `node runtime/smoke.mjs` from the plugin directory.
It tests MCP initialization, tool discovery, read_me, create_view, shared checkpoint
retrieval, editor saves and invalid inputs. It leaves one small smoke checkpoint.
For a visual check, open the Grove example and export PNG/SVG/Excalidraw. The example
was rendered and inspected through the bundled editor, and its saved elements were
verified unchanged after a container restart. `examples/grove.py` regenerates the
layout input; export it through the editor to obtain fully normalized scene data.

---
name: mcp-proxy-debugging
description: Debug the mcp-proxy launchd service (com.patrick.mcp-proxy) defined in nix-config modules/darwin/mcp-proxy.nix. Use when an MCP tool call fails with -32602, an MCP server won't start, the proxy is in a restart loop, or all MCP servers stopped working at once. Covers the two distinct failure classes: a child server crashing at init (pnpm dlx broken peer deps) and a stale SSE session.
---

# Debugging mcp-proxy

mcp-proxy runs as a launchd user agent (`com.patrick.mcp-proxy`) defined in `modules/darwin/mcp-proxy.nix`. It serves several stdio MCP servers (claude-orchestrator, Gitlab, google-private, google-work) over a local SSE endpoint on port 8765. Each server is spawned through a wrapper script that sources `~/.secrets-env` so children inherit tokens.

**Always start by reading the log:** `~/Library/Logs/mcp-proxy.log`. The two failure classes below look different in the log and have different fixes. Do not guess.

## Failure class 1 — a child server crashes at init (pnpm dlx broken peers)

**Symptom:** an MCP server fails to start. Log shows:
```
Error [ERR_MODULE_NOT_FOUND]: Cannot find package 'X'
```
where X is a transitive dep (e.g. `@modelcontextprotocol/sdk`). Often **every** MCP server stops working, because when any stdio child crashes at init, mcp-proxy aborts the whole proxy and launchd (`KeepAlive = true`) restarts it in a loop. `launchctl list | grep mcp` shows the service flapping.

**Cause:** pnpm's strict isolated linker only puts a package's *declared* deps in its `node_modules`. Some MCP packages import sibling deps they don't declare. This works under npm's flatter layout, fails under `pnpm dlx`. `node-linker=hoisted` and `--package=X` are ignored by `pnpm dlx`, so there is no pnpm-side fix.

**Fix:** switch that server's `command` in `mcp-proxy.nix` from the pnpm wrapper to the npx wrapper. The file already defines `npxWrapper` (`npx --yes`) and `npxWorkWrapper` (adds `GOOGLE_MCP_PROFILE=work`) for exactly this. The `google-private` and `google-work` servers already use npx for this reason — copy that pattern. Then:
```bash
nix run .#build-switch
launchctl kickstart -k gui/$(id -u)/com.patrick.mcp-proxy
```

## Failure class 2 — stale SSE session (-32602)

**Symptom:** an MCP tool call returns `MCP error -32602: Invalid request parameters`. Do NOT assume wrong params or a server-side validation bug. The proxy log shows the real cause:
```
[W ...] Failed to validate request: Received request before initialization was complete
```

**Cause:** the Claude Code SSE session is reusing a `session_id` that mcp-proxy no longer considers initialized. The upstream server is fine (running it directly with a JSON-RPC `initialize` payload returns a proper handshake).

**Fix:**
```bash
launchctl kickstart -k gui/$(id -u)/com.patrick.mcp-proxy
```
then `/mcp` in Claude Code to drop the stale session and reconnect.

**Misdiagnosis traps:** it is NOT an auth/token problem (re-auth changes nothing) and NOT multi-account ambiguity (param-less calls fail the same way). The pattern (proxy log says "before initialization was complete" while the client sees -32602) is generic to mcp-proxy SSE sessions.

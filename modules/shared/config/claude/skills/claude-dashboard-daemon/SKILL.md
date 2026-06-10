---
name: claude-dashboard-daemon
description: Understand and debug the claude-dashboard launchd service (com.patrick.claude-dashboard) on this Mac — when https://clawde.localhost is down, returns 404/502, won't start, serves a stale build, or launchd shows it "running" while it actually isn't. Covers the architecture, the serving-port-changes-each-launch trap, the zombie-parent KeepAlive blind spot, and the restart.
---

# Debug the claude-dashboard daemon

The dashboard at **https://clawde.localhost** is a launchd user agent. This is the runbook for "it's not running / not reachable".

## Architecture (know this before touching anything)

- **Agent:** `com.patrick.claude-dashboard`, plist at `~/Library/LaunchAgents/com.patrick.claude-dashboard.plist`.
- **Nix source:** `modules/darwin/claude-dashboard.nix` in `~/nix-config`. Edit there + `build-switch`, never the plist.
- **What it runs:** a wrapper script (`zsh -l`) that sources `~/.zshenv` and `~/.secrets-env`, then `exec pnpm dlx --allow-build=node-pty @instaffo/claude-dashboard`. So **every launch re-resolves the package from the GitLab npm registry** (group `2066742`) — startup hits the network and can be slow.
- **Logs:** `~/Library/Logs/claude-dashboard.log` (stdout+stderr).
- **`KeepAlive=true`, `RunAtLoad=true`.**
- **The proxy is a separate service.** The dashboard listens on `127.0.0.1:<random-high-port>`; `portless` fronts it at `https://clawde.localhost:443`. portless runs as its own **root LaunchDaemon** `com.patrick.portless-proxy` (also in `claude-dashboard.nix`), `portless proxy start --foreground`, gated on the `/nix` mount via `wait4path`. Two services, two failure points.

Process chain: `wrapper(zsh)` → `exec pnpm(node)` → dashboard bin → `server.js` (the actual HTTP server) + a `portless` client. The port is **picked fresh on every launch** — it is NOT fixed at 4936.

## Two traps that cause wrong diagnoses

1. **The serving port changes every launch.** `curl localhost:4936` failing means nothing if this launch chose 4713. Always read the current port from the log (Step 3). Test `https://clawde.localhost` for the real user-facing answer.
2. **A live launchd pid lies.** The `pnpm dlx` parent can stay alive after the inner `server.js` dies — a pending retry timer (slow/failing registry update-check) keeps Node's event loop alive. launchd sees a live pid, so **`KeepAlive` never restarts it**, and you get a live process serving nothing. `launchctl list` showing a pid is NOT proof the dashboard works.

## Runbook

```bash
# 1. launchd's view (pid + last exit) — necessary, not sufficient (see trap 2)
launchctl list | grep claude-dashboard
launchctl print "gui/$(id -u)/com.patrick.claude-dashboard" | grep -iE "state|pid|last exit|program"

# 2. The real test: the user-facing endpoint via the proxy
curl -sk -o /dev/null -w "clawde -> %{http_code}\n" --max-time 5 https://clawde.localhost/
#   200          -> it's fine, look elsewhere
#   404/502/000  -> backend down or proxy down; keep going

# 3. Find the ACTUAL serving port this launch chose, then hit it directly
grep "Dashboard server running" ~/Library/Logs/claude-dashboard.log | tail -1
PORT=$(grep -oE "localhost:[0-9]+" ~/Library/Logs/claude-dashboard.log | tail -1 | cut -d: -f2)
curl -s -o /dev/null -w "backend $PORT -> %{http_code}\n" --max-time 5 "http://localhost:$PORT/"
#   backend 200 but clawde !=200 -> PROXY problem (Step 6)
#   backend 000/refused          -> dashboard server is dead (zombie parent, trap 2)

# 4. Read the log — but filter the fd-warning spam first (thousands of lines of
#    "File descriptor N opened in unmanaged mode"; harmless node-pty noise)
grep -vE "File descriptor|unmanaged mode|trace-warnings|Progress:" ~/Library/Logs/claude-dashboard.log | tail -30
#   "error (23)" / "Request took 70000ms" = NETWORK TIMEOUT to the registry,
#   not auth. gitlab.com and even registry.npmjs.org can be 60-70s/req during
#   incidents. Token blame? -> use the test-gitlab-token skill, don't guess.

# 5. Restart (fixes the zombie-parent case)
launchctl kickstart -k "gui/$(id -u)/com.patrick.claude-dashboard"
#   startup re-runs `pnpm dlx` (network); can take 60-90s on a slow registry.
#   Poll the proxy with retries instead of sleeping:
curl -sk -o /dev/null -w "clawde -> %{http_code}\n" --retry 24 --retry-delay 5 \
  --retry-all-errors --max-time 5 https://clawde.localhost/
```

## If backend is up but clawde.localhost is not (proxy problem)

```bash
sudo launchctl print "system/com.patrick.portless-proxy" | grep -iE "state|pid|last exit"
sudo launchctl kickstart -k system/com.patrick.portless-proxy   # root daemon, needs sudo
tail -30 ~/Library/Logs/portless-proxy.log
```
The proxy daemon is gated on `/nix` being mounted; on a missing-executable failure launchd parks it and KeepAlive won't retry (that's why the nix def wraps it in `wait4path`). A manual kickstart clears it.

## Quick verdict table

| Observation | Cause | Action |
|---|---|---|
| `launchctl` pid present, `clawde` 404, backend port refused | zombie `pnpm dlx` parent; server died, KeepAlive blind | `kickstart -k` the agent (Step 5) |
| backend port 200, `clawde` 000/404 | portless proxy down | kickstart `portless-proxy` (sudo) |
| log full of `error (23)` / 70s requests | registry/network slowness, not auth | wait/retry; verify token via test-gitlab-token only if it persists |
| serves an old version number | `pnpm dlx` resolved a cached/old release | `kickstart -k`; if stuck, check registry reachability |
| nothing in log, no pid | agent not loaded | `launchctl print` for the bootstrap error; re-run `build-switch` |

## Rules

- Fix config in `modules/darwin/claude-dashboard.nix` then `nix run .#build-switch` (needs sudo, user runs it). Never edit the generated plist.
- `kickstart -k` is safe and reversible — it's the first move for a hung/dead agent.
- Don't trust a live pid. Don't hardcode the port. Don't assume `error (23)` is the token.

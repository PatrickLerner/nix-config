---
name: test-gitlab-token
description: Test whether a GitLab token is valid, what scopes and expiry it has, and whether it can read a private npm package from the GitLab package registry. Use when a gitlab.com request returns 401, an npm/pnpm install of an @instaffo-scoped package fails or hangs, or you need to confirm a token before blaming it. Covers the trap where ~/.npmrc holds a literal ${ENV_VAR} reference, not a raw token.
---

# Test a GitLab token

Goal: decide in under a minute whether a token is the problem. Most "401 / install fails" reports are NOT an expired token. Confirm before blaming it.

## Step 0 — get the actual token value (the trap)

`~/.npmrc` and `~/.config/npm/npmrc` often store an **env-var reference**, not the token:

```
//gitlab.com/:_authToken=${GITLAB_PERSONAL_ACCESS_TOKEN}
```

pnpm/npm expand `${VAR}` from the environment at runtime. If you `grep` the file and test that string, you are testing the literal text `${GITLAB_PERSONAL_ACCESS_TOKEN}` — guaranteed 401, and a false conclusion.

Resolve it first:

```bash
# pull every ${VAR} the npmrc references, show whether each is set in env
grep -oE '\$\{[A-Za-z_][A-Za-z0-9_]*\}' "$HOME/.npmrc" | tr -d '${}' | sort -u | \
  while read v; do printf "%s = %s\n" "$v" "$(eval echo \"\$$v\" | cut -c1-6)…"; done
```

A real GitLab personal access token starts with `glpat-`. If you see `${…` you are holding the unexpanded reference — export/source the env first (it may come from `~/.secrets-env`, a shell profile, or agenix). Set `TOKEN` to the **expanded** value for the rest of this skill.

## Step 1 — is the token valid at all?

GitLab accepts two header styles. Personal access tokens (`glpat-`) work with either; test `PRIVATE-TOKEN` first:

```bash
curl -s -o /dev/null -w "PRIVATE-TOKEN: %{http_code}\n" -H "PRIVATE-TOKEN: $TOKEN" https://gitlab.com/api/v4/user
curl -s -o /dev/null -w "Bearer:        %{http_code}\n" -H "Authorization: Bearer $TOKEN" https://gitlab.com/api/v4/user
```

- `200` → token is valid and not expired. Stop blaming the token.
- `401` → genuinely invalid/expired/revoked.
- `000` → **the request never completed** (timeout/network), NOT an auth result. Raise `--max-time` and retry; gitlab.com and even registry.npmjs.org can take 60–70 s per request during incidents. A slow registry looks like a dead service but is a network problem, not a token problem.

## Step 2 — scopes and expiry

```bash
curl -s -H "PRIVATE-TOKEN: $TOKEN" https://gitlab.com/api/v4/personal_access_tokens/self | \
  ruby -rjson -e 'd=JSON.parse(STDIN.read); puts "scopes=#{d["scopes"]} expires=#{d["expires_at"]} active=#{d["active"]}"'
```

For reading the npm package registry you need at least `read_api` (or `api`).

## Step 3 — end-to-end: can it actually read the package?

This is the test that matches what pnpm does. Group `2066742` is the InstaffoGmbH group.

```bash
# raw registry metadata endpoint
curl -s -o /dev/null -w "registry: %{http_code}\n" -H "Authorization: Bearer $TOKEN" \
  "https://gitlab.com/api/v4/groups/2066742/-/packages/npm/@instaffo%2Fclaude-dashboard"

# the real thing: pnpm using ~/.npmrc auth resolution (expands ${VAR} itself)
pnpm view @instaffo/claude-dashboard version
```

If `pnpm view` prints a version, auth + registry both work, regardless of what your raw curls said. Trust this over hand-rolled curls — it uses the same code path as the failing install.

## Decision

| Symptom | Verdict |
|---|---|
| `pnpm view` returns a version | Token and registry fine. Look elsewhere (the process, the port, a dead child). |
| Step 1 = `401` with the **expanded** token | Token expired/revoked. Mint a new one. |
| Step 1 = `000`, `pnpm view` slow but eventually succeeds | Registry/network slowness, not the token. Wait or retry. |
| You only ever tested the `${VAR}` literal | Invalid test. Go back to Step 0. |

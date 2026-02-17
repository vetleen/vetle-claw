# OpenClaw on Fly.io – deploy and ops

This app is deployed as **openclaw-fly-eu** on Fly.io (region **ams**), single machine, persistent volume at `/data`.

**For full context** (what we did, pitfalls, for agents/LLMs without prior context): see **`../AGENTS-CONTEXT.md`** (one level up from the repo, in the openclaw folder).

## Prerequisites

- `flyctl` installed and logged in (`fly auth login`)
- App and volume already created (see below if starting from scratch)

## Set secrets

Use the **fly-secrets.env** file (gitignored): copy `fly-secrets.env.example` to `fly-secrets.env`, paste your real values, then run:

```powershell
cd c:\openclaw\repo
.\scripts\fly-secrets-apply.ps1
```

That pushes every non-placeholder `KEY=value` from `fly-secrets.env` to Fly. Placeholder lines (e.g. `your-gateway-token-hex-32-chars`) are skipped.

To use the same vars in your own commands (e.g. in a script), load them in PowerShell:

```powershell
Get-Content fly-secrets.env | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$' -and $matches[2] -notmatch '^your-|^sk-your-') {
    Set-Item -Path "env:$($matches[1])" -Value $matches[2].Trim()
  }
}
# Then e.g. $env:OPENAI_API_KEY, $env:DISCORD_BOT_TOKEN are set
```

## Deploy

```powershell
cd c:\openclaw\repo
fly deploy
```

If `fly` isn’t in your current terminal’s PATH (e.g. in Cursor’s integrated terminal), use the wrapper:

```powershell
cd c:\openclaw\repo
.\scripts\fly.ps1 deploy
```

First deploy builds the image (~2–5 min). Later deploys are faster.

## Check status and logs

```powershell
fly status
fly logs
fly logs --no-tail   # recent logs only
```

You should see the gateway listening on `ws://0.0.0.0:3000` and, if configured, e.g. Discord logged in.

## Create or update config (openclaw.json)

Config path on the machine: **`/data/openclaw.json`** (because `OPENCLAW_STATE_DIR=/data`).

**Option A – SSH and create the file**

```powershell
fly ssh console
```

Then inside the console:

```bash
# Example: write a minimal config (adjust model/channels as needed)
cat > /data/openclaw.json << 'EOF'
{
  "agents": {
    "defaults": {
      "model": { "primary": "openai/gpt-4o" },
      "maxConcurrent": 2
    },
    "list": [{ "id": "main", "default": true }]
  },
  "bindings": [{ "agentId": "main", "match": { "channel": "discord" } }],
  "channels": { "discord": { "enabled": true, "groupPolicy": "allowlist", "guilds": {} } },
  "gateway": { "mode": "local", "bind": "auto" }
}
EOF
exit
```

**Option B – Use the Control UI**

1. Open https://openclaw-fly-eu.fly.dev/
2. Paste your **OPENCLAW_GATEWAY_TOKEN** when prompted
3. Use the config UI to edit and apply config (if available)

After changing `/data/openclaw.json`, restart the machine so the gateway picks it up:

```powershell
fly machines list
fly machine restart <machine-id>
```

Keep **secrets in Fly secrets** (API keys, Discord token); put only non-secret structure in `openclaw.json`.

### Persistent logs (optional)

By default, logs go to `/tmp/openclaw` and are lost on restart. To keep logs across restarts, set in your config (e.g. in `/data/openclaw.json`):

```json
"logging": { "file": "/data/logs/openclaw.log" }
```

Create the directory once via SSH if needed: `mkdir -p /data/logs`. Then restart the machine so the gateway picks up the config.

## Redeploy updates

```powershell
cd c:\openclaw\repo
git pull
fly deploy
fly status
fly logs
```

## Access the Control UI

- URL: **https://openclaw-fly-eu.fly.dev/**
- Auth: paste the value of `OPENCLAW_GATEWAY_TOKEN` (the one you set with `fly secrets set`). No public access without that token.

### Control UI doesn’t load

If the page never loads or hangs:

1. **Fly trial** – On a trial account the machine stops after ~5 minutes. Add a payment method in the Fly dashboard so the app stays running.
2. **Startup delay** – The gateway takes ~35 seconds to bind. If you hit the URL right after deploy, wait about a minute and refresh.
3. **Token in UI** – After the page loads, open the Control UI settings and paste your `OPENCLAW_GATEWAY_TOKEN` so the WebSocket can connect (otherwise you may see `token_missing` and the UI won’t work).

**Initial config:** A minimal `/data/openclaw.json` (Discord enabled, one agent) was created and the machine was restarted. You can edit it via the Control UI or by SSH (see “Create or update config” above).

### Give the Discord agent full exec access (e.g. Magda)

If the agent says it needs approval to run commands (e.g. `ls /app/skills/`), give it **full** exec access:

1. Open **https://openclaw-fly-eu.fly.dev/** and connect with your gateway token.
2. Go to **Nodes** in the sidebar.
3. In the **Exec approvals** card:
   - **Target** → **Host**: choose **Gateway** (and if you use a separate node, repeat the steps for that **Node**).
   - Click **Load approvals**.
   - **Scope**: choose **Defaults** (for all agents) or **main** (only the default agent).
   - **Security** → **Mode**: set to **Full** (no approval needed for execs).
   - Click **Save**.

After saving, the agent can run terminal commands (e.g. listing skills, running tools) without asking for approval each time.

## Troubleshooting

### "App is not listening on the expected address"

The proxy expects the app to listen on `0.0.0.0:3000`. If you see this warning:

1. Check logs: `fly logs --no-tail` for gateway startup or errors.
2. Restart the machine: `fly machine restart <machine-id>`.
3. From inside the machine, run the gateway by hand to see errors:
   ```powershell
   fly ssh console
   ```
   Then: `cd /app && node /app/dist/index.js gateway --allow-unconfigured --port 3000 --bind lan` and watch stderr.

### Gateway lock / "already running"

If the container restarts and you get lock errors:

```powershell
fly ssh console -C "rm -f /data/gateway.*.lock"
fly machine restart <machine-id>
```

### Config not read

- Ensure the file exists: `fly ssh console -C "cat /data/openclaw.json"`.
- Restart after editing: `fly machine restart <machine-id>`.

### 503 / "Machine exhausted its maximum restart attempts" / "Invalid config"

If the app exits on startup, the proxy never sees it listening on `0.0.0.0:3000` and returns 503. Check logs for the cause:

```powershell
fly logs --no-tail | Select-String -Pattern "Invalid config|listening|Main child exited"
```

- **`models.providers.moonshot.models: expected array, received undefined`**  
  The config has a `models.providers.moonshot` block with only `baseUrl` (or similar) and no `models` array. Either remove the whole `models.providers.moonshot` block (Moonshot still works via `MOONSHOT_API_KEY`), or add a valid `models` array there.

- **Wrong or missing fallback model**  
  If the default/fallback model ID (e.g. `openai/gpt-5.2`) is invalid or unavailable, the gateway can exit at startup. Switch to a known model (e.g. `openai/gpt-4o`) in `/data/openclaw.json`.

**Manual fix (interactive SSH):**

1. Start the machine: `fly machine start <machine-id> -a openclaw-fly-eu`
2. Open a console: `fly ssh console -a openclaw-fly-eu` (no `-C` so you get an interactive shell)
3. Fix the config. **Option A – overwrite with known-good config (recommended)**  
   Paste and run this whole block (one line; no `models.providers.moonshot`, fallback `openai/gpt-4o`):

   ```bash
   printf '%s' '{"messages":{"ackReactionScope":"group-mentions"},"agents":{"defaults":{"maxConcurrent":4,"model":{"primary":"moonshot/kimi-k2.5","fallbacks":["openai/gpt-4o"]},"subagents":{"maxConcurrent":8},"contextPruning":{"mode":"cache-ttl","ttl":"1h"},"heartbeat":{"every":"30m"},"compaction":{"mode":"safeguard"}},"list":[{"id":"main","default":true}]},"bindings":[{"agentId":"main","match":{"channel":"discord"}}],"channels":{"discord":{"enabled":true,"groupPolicy":"allowlist","guilds":{},"dm":{"allowFrom":["214033985829863424"]}}},"plugins":{"entries":{"discord":{"enabled":true}}},"gateway":{"mode":"local","bind":"auto"},"meta":{"lastTouchedVersion":"2026.2.6-3","lastTouchedAt":"2026-02-08T20:00:00.000Z"}}' > /data/openclaw.json
   ```

   **Option B – edit in place**  
   - Replace fallback only: `sed -e 's|openai/gpt-5.2|openai/gpt-4o|g' -i /data/openclaw.json`  
   - Or remove the invalid moonshot block: edit `/data/openclaw.json` and delete the entire `models.providers.moonshot` block (no `models` array causes the error).
4. Exit and restart: `fly machine restart <machine-id> -a openclaw-fly-eu`
5. Check logs until you see the gateway "listening" and no "Invalid config" or "Main child exited".

### EACCES: permission denied, open '/data/identity/device.json' (cron / browser tools)

Agents (e.g. Magda) need to read the device identity at `OPENCLAW_STATE_DIR/identity/device.json` for cron and browser tools. If that path was created as root or with wrong ownership, the node process gets EACCES.

**Fix:** Deploy the latest image. The entrypoint now ensures `$OPENCLAW_STATE_DIR/identity` exists and is owned by the `node` user before starting the gateway, so cron and browser tools can read `device.json`.

**One-time manual fix** (if you can’t redeploy yet): `fly ssh console`, then as root run:  
`mkdir -p /data/identity && chown -R node:node /data/identity`  
Then restart the machine.

### Stale deploy / change process command

To change the run command or VM without a full rebuild:

```powershell
fly machines list
fly machine update <machine-id> --command "node /app/dist/index.js gateway --allow-unconfigured --port 3000 --bind lan" -y
```

Note: a normal `fly deploy` will reset the command to whatever is in `fly.toml`.

## Repo and upstream

If you forked or cloned from the main OpenClaw repo and want to pull updates while keeping your Fly-specific changes:

1. **Add upstream (once):**  
   `git remote add upstream https://github.com/openclaw/openclaw.git`  
   (Use `origin` for your fork and `upstream` for the main repo, or adjust names as you prefer.)

2. **Pull updates:**  
   `git fetch upstream` then `git merge upstream/main` or `git rebase upstream/main`. Resolve conflicts as needed.

3. **Custom files to watch** when merging (we keep these tailored for this deployment; resolve conflicts by keeping our version or merging by hand):  
   - `fly.toml` – app name, region, env, mounts, process command  
   - `DEPLOY.md` – this doc (team procedures, URLs, troubleshooting)  
   - `fly-openclaw-merged.json`, `fly-openclaw-init.json` – config templates or merged defaults  
   - `fly-secrets.env.example` – example placeholders (never commit real secrets)

Keep `fly.toml` as the single source of truth in the repo (do not edit only on the server), so each `fly deploy` uses the same mounts, `OPENCLAW_STATE_DIR`, and port.

---

**Summary**

| Action            | Command / URL                                                |
|-------------------|--------------------------------------------------------------|
| Set secrets       | `fly secrets set OPENCLAW_GATEWAY_TOKEN=...` (and API/channel keys) |
| Deploy            | `fly deploy`                                                 |
| Logs              | `fly logs` or `fly logs --no-tail`                           |
| Status            | `fly status`                                                 |
| Config on volume  | SSH and edit `/data/openclaw.json`, then `fly machine restart <id>` |
| Control UI        | https://openclaw-fly-eu.fly.dev/ (token = OPENCLAW_GATEWAY_TOKEN) |

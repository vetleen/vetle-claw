# Set researcher agent sandbox.mode to "off" in /data/openclaw.json on Fly
# (Docker is not available in Fly app env; sandbox causes "spawn docker ENOENT".)
# Run from repo: .\scripts\fix-researcher-sandbox-off.ps1

$flyBin = Join-Path $env:USERPROFILE ".fly\bin"
if (Test-Path $flyBin) { $env:Path = "$flyBin;$env:Path" }

# One-liner: find researcher in agents.list and set sandbox.mode to "off"
$remoteCmd = 'python3 -c ''import json; c=json.load(open(\"/data/openclaw.json\")); next((a[\"sandbox\"].__setitem__(\"mode\",\"off\") for a in (c.get(\"agents\",{}) or {}).get(\"list\",[]) if a.get(\"id\")==\"researcher\" and a.get(\"sandbox\")), None); open(\"/data/openclaw.json\",\"w\").write(json.dumps(c,indent=2)); print(\"OK\")'''
fly ssh console -C $remoteCmd

Write-Host "Done. Restart machine: fly machine restart <id>"

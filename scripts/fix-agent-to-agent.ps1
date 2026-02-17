# Set agentToAgent.enabled and allow main + researcher in /data/openclaw.json on Fly
# Run from repo: .\scripts\fix-agent-to-agent.ps1

$flyBin = Join-Path $env:USERPROFILE ".fly\bin"
if (Test-Path $flyBin) { $env:Path = "$flyBin;$env:Path" }

# Single-quoted remote command; escape double quotes so they reach the remote shell
$remoteCmd = 'python3 -c ''import json; c=json.load(open(\"/data/openclaw.json\")); c.setdefault(\"tools\",{}); c[\"tools\"][\"agentToAgent\"]={\"enabled\":True,\"allow\":[\"main\",\"researcher\"]}; json.dump(c,open(\"/data/openclaw.json\",\"w\"),indent=2); print(\"OK\")'''
fly ssh console -C $remoteCmd

Write-Host "Done. Restart machine: fly machine restart <id>"

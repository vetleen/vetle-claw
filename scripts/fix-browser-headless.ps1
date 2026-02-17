# Set browser.headless and browser.noSandbox to true in /data/openclaw.json on Fly
# (Required for browser tool in containers; Chromium is installed in the image.)
# Run from repo: .\scripts\fix-browser-headless.ps1

$flyBin = Join-Path $env:USERPROFILE ".fly\bin"
if (Test-Path $flyBin) { $env:Path = "$flyBin;$env:Path" }

$remoteCmd = 'python3 -c ''import json; c=json.load(open(\"/data/openclaw.json\")); c.setdefault(\"browser\",{}); c[\"browser\"][\"headless\"]=True; c[\"browser\"][\"noSandbox\"]=True; open(\"/data/openclaw.json\",\"w\").write(json.dumps(c,indent=2)); print(\"OK: browser.headless and browser.noSandbox set to true\")'''
fly ssh console -C $remoteCmd

Write-Host "Done. Restart machine: fly machine restart <id>"

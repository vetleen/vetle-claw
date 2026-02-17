# Fix researcher agent workspaceAccess: ro -> rw
# Run: .\scripts\fix-researcher-workspace.ps1

$flyBin = Join-Path $env:USERPROFILE ".fly\bin"
if (Test-Path $flyBin) { $env:Path = "$flyBin;$env:Path" }

$nodeScript = @'
const fs = require('fs');
const p = '/data/openclaw.json';
const c = JSON.parse(fs.readFileSync(p, 'utf8'));
const r = c.agents?.list?.find(a => a.id === 'researcher');
if (r?.sandbox) r.sandbox.workspaceAccess = 'rw';
fs.writeFileSync(p, JSON.stringify(c, null, 2));
console.log('Updated researcher sandbox.workspaceAccess to rw');
'@

# Write script to temp file, scp it, run it, clean up
$tmpScript = [System.IO.Path]::GetTempFileName() + '.js'
$nodeScript | Set-Content -Path $tmpScript -Encoding utf8

fly ssh sftp shell -C "put $tmpScript /tmp/fix.js"
fly ssh console -C "node /tmp/fix.js"
fly ssh console -C "rm /tmp/fix.js"

Remove-Item $tmpScript -ErrorAction SilentlyContinue
Write-Host "Done. Restart machine: fly machine restart <id>"

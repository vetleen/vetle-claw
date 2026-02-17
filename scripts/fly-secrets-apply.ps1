# Apply fly-secrets.env to Fly.io (run from repo root).
# Usage:  .\scripts\fly-secrets-apply.ps1
# Or:     cd c:\openclaw\repo; .\scripts\fly-secrets-apply.ps1

$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not (Test-Path (Join-Path $repoRoot "fly.toml"))) {
    $repoRoot = Get-Location
}
$envFile = Join-Path $repoRoot "fly-secrets.env"
if (-not (Test-Path $envFile)) {
    Write-Error "Not found: $envFile. Copy fly-secrets.env.example to fly-secrets.env and add your values."
    exit 1
}

$flyctl = Join-Path $env:USERPROFILE ".fly\bin\flyctl.exe"
if (-not (Test-Path $flyctl)) {
    $flyctl = "flyctl"
}

Push-Location $repoRoot
try {
    $lines = Get-Content $envFile -Encoding UTF8
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        if ($line -notmatch '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') { continue }
        $key = $matches[1]
        $value = $matches[2].Trim()
        if ($value -eq "" -or $value -match '^your-|^sk-your-') {
            Write-Host "Skipping placeholder: $key"
            continue
        }
        Write-Host "Setting secret: $key"
        & $flyctl secrets set "${key}=$value" 2>&1
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    Write-Host "Done. Run 'fly deploy' if the app is already created."
}
finally {
    Pop-Location
}

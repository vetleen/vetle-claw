# Run Fly CLI from repo (works even when fly isn't in current session PATH).
# Usage:  .\scripts\fly.ps1 deploy
#         .\scripts\fly.ps1 status
#         .\scripts\fly.ps1 ssh console
# Or:     cd c:\openclaw\repo; .\scripts\fly.ps1 deploy

$flyBin = Join-Path $env:USERPROFILE ".fly\bin"
if (Test-Path $flyBin) {
    $env:Path = "$flyBin;$env:Path"
}
$flyctl = "flyctl"
if (Test-Path (Join-Path $flyBin "flyctl.exe")) {
    $flyctl = Join-Path $flyBin "flyctl.exe"
}
& $flyctl @args

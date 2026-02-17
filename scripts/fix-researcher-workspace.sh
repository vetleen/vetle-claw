#!/bin/sh
# Fix researcher agent workspaceAccess: ro -> rw
# Run on Fly: fly ssh console < fix-researcher-workspace.sh
sed -i 's/"workspaceAccess": "ro"/"workspaceAccess": "rw"/' /data/openclaw.json
echo "Done. workspaceAccess updated."
grep workspaceAccess /data/openclaw.json

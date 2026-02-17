#!/bin/sh
# If OPENCLAW_STATE_DIR is set and openclaw.json exists but is invalid JSON, remove it
# so the gateway can start with --allow-unconfigured (empty config) instead of exiting.
if [ -n "$OPENCLAW_STATE_DIR" ]; then
  CFG="$OPENCLAW_STATE_DIR/openclaw.json"
  if [ -f "$CFG" ]; then
    node -e "
      try {
        const fs = require('fs');
        const p = process.env.OPENCLAW_STATE_DIR + '/openclaw.json';
        const raw = fs.readFileSync(p, 'utf8');
        JSON.parse(raw);
      } catch (e) {
        try { require('fs').unlinkSync(process.env.OPENCLAW_STATE_DIR + '/openclaw.json'); } catch (_) {}
        process.exit(1);
      }
    " 2>/dev/null || true
  fi
fi

# Ensure state dir identity subtree is owned by node so cron/browser tools can read device.json.
# When running as root (e.g. container default), create dir and chown; then run main process as node.
if [ -n "$OPENCLAW_STATE_DIR" ] && [ "$(id -u)" = "0" ]; then
  mkdir -p "$OPENCLAW_STATE_DIR/identity"
  chown -R node:node "$OPENCLAW_STATE_DIR/identity" 2>/dev/null || true
  # Use su to switch to node user and exec the command
  # su with -c needs the command as a single string, so we rebuild it
  # Simple approach: wrap each arg in single quotes, escape single quotes within
  CMD=""
  for arg in "$@"; do
    # Replace single quotes with: ' (end quote) + "'" (escaped quote) + ' (start quote)
    arg_escaped=$(echo "$arg" | sed "s/'/'\''/g")
    CMD="$CMD '${arg_escaped}'"
  done
  exec su -s /bin/sh node -c "exec $CMD"
fi

exec "$@"

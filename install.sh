#!/bin/bash
# Install the synergy fleet: three Claude tier agents + the fleet-run dispatcher.
# Idempotent - re-run any time. SYNERGY_SKIP_CHECK=1 skips the live agent check.
set -uo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
agents_dir="$HOME/.claude/agents"
bin_dir="${SYNERGY_BIN_DIR:-$HOME/.local/bin}"

mkdir -p "$agents_dir" "$bin_dir" || exit 1
cp "$src"/agents/*.md "$agents_dir"/ || exit 1
cp "$src/fleet-run" "$bin_dir/fleet-run" || exit 1
chmod 755 "$bin_dir/fleet-run"

echo "installed:"
echo "  $agents_dir/{genius-fable,genius-opus,worker-sonnet}.md"
echo "  $bin_dir/fleet-run"

case ":$PATH:" in
  *":$bin_dir:"*) ;;
  *) echo; echo "NOTE: $bin_dir is not on your PATH - add it to your shell profile:"
     echo "  export PATH=\"$bin_dir:\$PATH\"" ;;
esac

echo
echo "Add this to permissions.allow in ~/.claude/settings.json (and autoMode.allow if you use auto mode):"
echo '  "Bash(fleet-run:*)"'
echo "You have to add it yourself - an agent cannot widen its own permissions."

echo
echo "Authenticate whichever agents you want (each is separate, no shared credential):"
command -v claude >/dev/null || echo "  claude: not installed - https://docs.claude.com/en/docs/claude-code"
command -v agy    >/dev/null || echo "  agy:    not installed - skip it, or install it and re-run"
command -v muse   >/dev/null || echo "  muse:   not installed - skip it, or install it and re-run"
echo "  logged out? claude -> /login   |   agy -> run 'agy'   |   muse -> 'muse login'"

if [[ "${SYNERGY_SKIP_CHECK:-}" == 1 ]]; then
  echo; echo "skipped the live check (SYNERGY_SKIP_CHECK=1). Run: fleet-run selftest"
  exit 0
fi

echo
echo "checking the fleet (a FAIL just means that agent is unavailable - route around it):"
"$bin_dir/fleet-run" selftest

echo
echo "The three named tiers resolve in your NEXT session (agent files load at startup)."

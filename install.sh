#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Install codex-call wrapper
mkdir -p ~/.claude/bin
cp "$SCRIPT_DIR/codex-call" ~/.claude/bin/codex-call
chmod +x ~/.claude/bin/codex-call
echo "Installed: ~/.claude/bin/codex-call"

# Install slash command template
mkdir -p ~/.claude/commands
cp "$SCRIPT_DIR/dual-agent.md" ~/.claude/commands/dual-agent.md
echo "Installed: ~/.claude/commands/dual-agent.md"

echo ""
echo "Done. Use in Claude Code: /dual-agent your requirement here"

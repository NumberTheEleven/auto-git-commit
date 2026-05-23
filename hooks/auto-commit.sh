#!/usr/bin/env bash
set -euo pipefail

YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# ── Find project root (where .git is) ──
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$PROJECT_ROOT" ]; then
    CONFIG_FILE="$PROJECT_ROOT/.claude/auto-commit.json"
else
    CONFIG_FILE=".claude/auto-commit.json"
fi

# ═══════════════════════════════════════════════
# Gate 1: Project-level opt-in
# ═══════════════════════════════════════════════
if [ ! -f "$CONFIG_FILE" ]; then
    # Project not opted in — silent exit
    exit 0
fi

# Check enabled flag
ENABLED=$(python3 -c "import json; d=json.load(open('$CONFIG_FILE')); print(d.get('enabled', True))" 2>/dev/null || echo "true")
if [ "$ENABLED" != "True" ] && [ "$ENABLED" != "true" ]; then
    exit 0
fi

# ═══════════════════════════════════════════════
# Gate 2: Must be a git repo
# ═══════════════════════════════════════════════
if ! git rev-parse --git-dir &>/dev/null; then
    echo -e "${YELLOW}[auto-git-commit] 当前目录不是 git 仓库。${NC}"
    echo "  运行 /auto-git-commit:init 初始化并接入自动提交。"
    exit 0
fi

# ═══════════════════════════════════════════════
# Gate 3: Must have changes
# ═══════════════════════════════════════════════
if [ -z "$(git status --porcelain)" ]; then
    exit 0
fi

# ═══════════════════════════════════════════════
# Gate 4: Check for remote (warn but allow local commit)
# ═══════════════════════════════════════════════
HAS_REMOTE=true
if ! git remote get-url origin &>/dev/null; then
    HAS_REMOTE=false
fi

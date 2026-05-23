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

# ═══════════════════════════════════════════════
# Security scanning
# ═══════════════════════════════════════════════

# Load exceptions from config
load_exceptions() {
    local patterns=""
    if [ -f "$CONFIG_FILE" ]; then
        patterns=$(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
exceptions = data.get('security', {}).get('exceptions', [])
for e in exceptions:
    print(e.get('pattern', ''))
" 2>/dev/null || echo "")
    fi
    echo "$patterns"
}

# Scan staged + unstaged + untracked files for secrets
scan_secrets() {
    local exceptions
    exceptions=$(load_exceptions)
    
    # High-severity patterns (block commit)
    local high_patterns=(
        'sk-[a-z0-9]{32,}'
        '-----BEGIN .*PRIVATE KEY-----'
        '(password|passwd|secret|token)\s*=\s*["'"'"'][^"'"'"']{8,}["'"'"']'
        'ghp_[a-zA-Z0-9]{36}'
        'xox[baprs]-[a-zA-Z0-9-]+'
    )
    
    local found_any=false
    
    # Get list of changed files (including untracked)
    while IFS= read -r file; do
        if [ -z "$file" ]; then continue; fi
        # Skip binary files
        if ! grep -Iq . "$file" 2>/dev/null; then continue; fi
        
        local line_num=0
        while IFS= read -r line; do
            line_num=$((line_num + 1))
            for pattern in "${high_patterns[@]}"; do
                if echo "$line" | grep -qE "$pattern" 2>/dev/null; then
                    # Check if this match is in exceptions
                    local is_exception=false
                    if [ -n "$exceptions" ]; then
                        while IFS= read -r exc; do
                            if [ -n "$exc" ] && echo "$line" | grep -qF "$exc" 2>/dev/null; then
                                is_exception=true
                                break
                            fi
                        done <<< "$exceptions"
                    fi
                    
                    if [ "$is_exception" = false ]; then
                        local snippet="${line:0:80}"
                        echo "  $file:$line_num: $snippet"
                        found_any=true
                    fi
                    break
                fi
            done
        done < "$file"
    done < <(git diff --cached --name-only 2>/dev/null; git diff --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null | head -100)
    
    if [ "$found_any" = true ]; then
        return 1
    fi
    return 0
}

# ═══════════════════════════════════════════════
# Gate 5: Security scan before commit
# ═══════════════════════════════════════════════
SECURITY_ISSUES=$(scan_secrets)
if [ $? -ne 0 ]; then
    echo -e "${RED}[auto-git-commit] 发现疑似敏感信息，提交已阻止。${NC}"
    echo "$SECURITY_ISSUES"
    echo ""
    echo "  如果是误判，运行 /auto-git-commit:check 逐项确认并加入白名单。"
    echo "  如果确实危险，请立即处理（替换为环境变量 / 加入 .gitignore）。"
    exit 0
fi

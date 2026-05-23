---
description: 查看 auto-git-commit 的全局和当前项目状态
allowed-tools: Bash(cat:*), Bash(echo:*), Bash(grep:*), Bash(git:*), Bash(python:*), Bash(ls:*), Bash(find:*)
---

## Overview

Display the current status of auto-git-commit: global hook registration, project-level configuration, git state, and security exception count.

## Step 1: Check global hook status

```bash
echo "=== auto-git-commit 状态 ==="
echo ""

# Global hook
if [ -x "$HOME/.claude/hooks/auto-commit.sh" ]; then
    echo "全局: ✓ Stop hook 已部署"
else
    echo "全局: ✗ Stop hook 未部署"
    echo "  运行 /auto-git-commit:enable 进行全局设置"
fi

if grep -q "auto-commit.sh" "$HOME/.claude/settings.json" 2>/dev/null; then
    echo "      ✓ Hook 已注册"
else
    echo "      ✗ Hook 未注册"
fi

echo ""
```

## Step 2: Check project status

```bash
# Project config
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
CONFIG="$PROJECT_ROOT/.claude/auto-commit.json"
if [ -f "$CONFIG" ]; then
    ENABLED=$(python -c "import json; d=json.load(open('$CONFIG')); print(d.get('enabled', True))" 2>/dev/null || echo "unknown")
    REMOTE=$(python -c "import json; d=json.load(open('$CONFIG')); print(d.get('remote', {}).get('url', 'N/A'))" 2>/dev/null || echo "N/A")
    EXCEPTIONS_COUNT=$(python -c "import json; print(len(json.load(open('$CONFIG')).get('security', {}).get('exceptions', [])))" 2>/dev/null || echo "0")
    CREATED=$(python -c "import json; d=json.load(open('$CONFIG')); print(d.get('createdAt', 'N/A'))" 2>/dev/null || echo "N/A")

    LANG_PREF=$(python -c "import json; d=json.load(open('$CONFIG')); print(d.get('language', 'zh'))" 2>/dev/null || echo "zh")
    PUSH_TO=$(python -c "import json; d=json.load(open('$CONFIG')); print(d.get('pushTimeout', 60))" 2>/dev/null || echo "60")

    echo "项目: ✓ 已接入"
    echo "      接入时间: $CREATED"
    echo "      状态: $([ "$ENABLED" = "True" ] && echo '启用' || echo '已暂停')"
    echo "      语言: $([ "$LANG_PREF" = "en" ] && echo '英文' || echo '中文')"
    echo "      推送超时: ${PUSH_TO}s"
    echo "      Remote: $REMOTE"
    echo "      安全白名单: $EXCEPTIONS_COUNT 条"

    # Show exception details
    if [ "$EXCEPTIONS_COUNT" -gt 0 ]; then
        echo ""
        echo "  白名单详情："
        python -c "
import json
with open('$CONFIG') as f:
    data = json.load(f)
for i, e in enumerate(data.get('security', {}).get('exceptions', [])):
    print(f\"    [{i}] {e.get('file', '?')}:{e.get('line', '?')} — {e.get('pattern', '?')[:60]}\")
    print(f\"        原因: {e.get('reason', 'N/A')}\")
" 2>/dev/null
    fi
else
    echo "项目: ✗ 未接入"
    echo "  运行 /auto-git-commit:init 接入当前项目"
fi

echo ""
```

## Step 3: Check git state

```bash
if git rev-parse --git-dir &>/dev/null; then
    BRANCH=$(git branch --show-current)
    LAST_COMMIT=$(git log -1 --format="%s (%cr)" 2>/dev/null || echo "无提交")
    CHANGES=$(git status --porcelain 2>/dev/null | wc -l)

    echo "Git:  ✓ 仓库"
    echo "      分支: $BRANCH"
    echo "      最后提交: $LAST_COMMIT"
    echo "      待提交变更: $CHANGES 个文件"

    # Dry-run: show what would be committed
    if [ "$CHANGES" -gt 0 ]; then
        echo ""
        echo "  [dry-run] 以下文件将在会话结束时被提交："
        # Staged files
        STAGED=$(git diff --cached --name-status 2>/dev/null)
        if [ -n "$STAGED" ]; then
            echo "$STAGED" | while IFS= read -r line; do echo "    [暂存] $line"; done
        fi
        # Modified (unstaged) files
        MODIFIED=$(git diff --name-status 2>/dev/null)
        if [ -n "$MODIFIED" ]; then
            echo "$MODIFIED" | while IFS= read -r line; do echo "    [修改] $line"; done
        fi
        # Untracked files
        UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -50)
        if [ -n "$UNTRACKED" ]; then
            echo "$UNTRACKED" | while IFS= read -r file; do echo "    [新增] $file"; done
        fi
    fi
else
    echo "Git:  ✗ 非 git 仓库"
fi
```

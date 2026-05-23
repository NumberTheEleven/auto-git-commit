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
if [ -f ".claude/auto-commit.json" ]; then
    ENABLED=$(python -c "import json; print(json.load(open('.claude/auto-commit.json')).get('enabled', True))" 2>/dev/null || echo "unknown")
    REMOTE=$(python -c "import json; print(json.load(open('.claude/auto-commit.json')).get('remote', {}).get('url', 'N/A'))" 2>/dev/null || echo "N/A")
    EXCEPTIONS_COUNT=$(python -c "import json; print(len(json.load(open('.claude/auto-commit.json')).get('security', {}).get('exceptions', [])))" 2>/dev/null || echo "0")
    CREATED=$(python -c "import json; print(json.load(open('.claude/auto-commit.json')).get('createdAt', 'N/A'))" 2>/dev/null || echo "N/A")

    echo "项目: ✓ 已接入"
    echo "      接入时间: $CREATED"
    echo "      状态: $([ "$ENABLED" = "True" ] && echo '启用' || echo '已暂停')"
    echo "      Remote: $REMOTE"
    echo "      安全白名单: $EXCEPTIONS_COUNT 条"
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
else
    echo "Git:  ✗ 非 git 仓库"
fi
```

---
description: 初始化当前项目的自动 git 提交（git init + remote 配置 + 首次提交 + 安全扫描）
allowed-tools: Bash(mkdir:*), Bash(cp:*), Bash(chmod:*), Bash(cat:*), Bash(echo:*), Bash(find:*), Bash(grep:*), Bash(python:*), Bash(git:*), Bash(gh:*), Bash(cygpath:*), Bash(date:*), Bash(head:*), Bash(ls:*), Bash(curl:*)
---

## Overview

Initialize the current project for auto-git-commit. Handles git init, remote configuration, first commit, security scanning, and project config file creation. All interactive confirmation happens here — NOT in the Stop hook.

## Step 1: Detect current state

```bash
echo "=== auto-git-commit init ==="
echo ""

# Check git repository
if git rev-parse --git-dir &>/dev/null; then
    echo "✓ 当前目录已是 git 仓库"
    IS_NEW_REPO=false
else
    echo "○ 当前目录不是 git 仓库，将执行 git init"
    IS_NEW_REPO=true
fi

# Check remote
if git remote get-url origin &>/dev/null 2>/dev/null; then
    echo "✓ 已配置 remote: $(git remote get-url origin)"
    HAS_REMOTE=true
else
    echo "○ 未配置远端仓库"
    HAS_REMOTE=false
fi

# Check commits
COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "0")
if [ "$COMMIT_COUNT" -gt 0 ]; then
    echo "✓ 已有 $COMMIT_COUNT 个提交"
    HAS_COMMITS=true
else
    echo "○ 尚无提交记录"
    HAS_COMMITS=false
fi

# Check existing config
if [ -f ".claude/auto-commit.json" ]; then
    echo "○ .claude/auto-commit.json 已存在"
    CONFIG_EXISTS=true
else
    CONFIG_EXISTS=false
fi
```

## Step 2: git init (if needed)

If `$IS_NEW_REPO` is true, run:

```bash
git init
git branch -M main
echo "✓ git 仓库已初始化，默认分支: main"
```

Ask the user: "是否继续？[Y/n]". If the user says no, explain that the project needs a git repo for auto-commit to work, and exit.

## Step 3: Configure remote (if needed)

If `$HAS_REMOTE` is false, ask the user:

> "项目还没有配置远端仓库。你想怎么处理？"
> Options:
> 1. 输入 GitHub 仓库 URL（已有仓库）
> 2. 自动创建新 GitHub 仓库（需要已登录 gh CLI）
> 3. 跳过（仅本地提交，不推送）

For option 1:

```bash
# The URL is provided by the user; validate and add
git remote add origin "<user-provided-url>"
echo "✓ remote origin 已添加"
```

For option 2:

```bash
# Check gh auth
if ! gh auth status &>/dev/null; then
    echo "gh CLI 未登录，请先运行 'gh auth login'"
    exit 1
fi
# Create repo
gh repo create "$(basename "$(pwd)")" --private --source=. --remote=origin --push
echo "✓ GitHub 仓库已创建并关联"
```

## Step 4: First commit (if no commits)

If `$HAS_COMMITS` is false:

```bash
git add -A

# Generate init message
PROJECT_INFO="Project structure:"$'\n'"$(ls -laR 2>/dev/null | head -150)"$'\n'
for f in package.json README.md Makefile pyproject.toml go.mod Cargo.toml docker-compose.yml Dockerfile; do
    if [ -f "$f" ]; then
        PROJECT_INFO="$PROJECT_INFO"$'\n'"=== $f ==="$'\n'"$(head -50 "$f")"$'\n'
    fi
done

MSG=$(claude -p \
"根据以下项目信息，用中文生成一行初始化提交信息（如 '新增: 初始化 React + TypeScript 博客项目'）。只返回提交信息，不要其他内容。

$PROJECT_INFO" 2>/dev/null) || MSG=""

if [ -z "${MSG//[[:space:]]/}" ]; then
    MSG="杂项: 项目初始化 $(date '+%Y-%m-%d')"
fi

git commit -m "$MSG"
echo "✓ 首次提交: $MSG"
```

## Step 5: Test push

```bash
if git remote get-url origin &>/dev/null 2>/dev/null; then
    echo "测试推送..."
    if git push 2>&1; then
        echo "✓ 推送成功"
    else
        echo "⚠ 推送测试失败，请检查远端配置。commit 已保存在本地。"
    fi
fi
```

## Step 6: Security scan (delegate to /auto-git-commit:check)

> "初始化即将完成。是否进行安全扫描，检查项目中是否存在硬编码的 API key、密码等敏感信息？[Y/n]"

If yes, tell the user: "运行 /auto-git-commit:check 进行安全扫描" and run it now as part of init.

## Step 7: Write config file

```bash
REMOTE_URL=""
if git remote get-url origin &>/dev/null 2>/dev/null; then
    REMOTE_URL=$(git remote get-url origin)
fi

mkdir -p .claude

python -c "
import json, datetime
config = {
    'enabled': True,
    'createdAt': datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ'),
    'remote': {
        'type': 'github',
        'url': '$REMOTE_URL'
    },
    'security': {
        'exceptions': []
    }
}
with open('.claude/auto-commit.json', 'w') as f:
    json.dump(config, f, indent=2)
"
echo "✓ .claude/auto-commit.json 已创建"
```

## Step 8: Summary

```
echo ""
echo "============================================"
echo "  auto-git-commit 初始化完成！"
echo "============================================"
echo ""
echo "  每次会话结束时，Stop hook 会自动检测变更、提交并推送。"
echo ""
echo "  常用命令："
echo "    /auto-git-commit:status   查看状态"
echo "    /auto-git-commit:check    安全扫描"
echo "    /auto-git-commit:disable  暂停自动提交"
echo ""
```

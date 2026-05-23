---
description: 撤销当前项目的自动 git 提交
allowed-tools: Bash(cat:*), Bash(echo:*), Bash(grep:*), Bash(git:*), Bash(python:*), Bash(ls:*), Bash(rm:*), Bash(mkdir:*)
---

## Overview

Disable auto-git-commit for the current project. The project-level config file is kept but `enabled` is set to false, so you can re-enable later.

## Step 1: Check current state

```bash
if [ ! -f ".claude/auto-commit.json" ]; then
    echo "当前项目未接入 auto-git-commit。"
    echo "运行 /auto-git-commit:init 接入。"
    exit 0
fi

echo "当前项目已接入 auto-git-commit。"
echo ""
echo "禁用后，Stop hook 将跳过此项目。"
echo ".claude/auto-commit.json 会保留，可以随时重新启用。"
```

## Step 2: Confirm

Ask the user: "确认禁用当前项目的自动 git 提交？[Y/n]"

## Step 3: Disable

If confirmed:

```bash
python3 -c "
import json
with open('.claude/auto-commit.json', 'r') as f:
    data = json.load(f)
data['enabled'] = False
with open('.claude/auto-commit.json', 'w') as f:
    json.dump(data, f, indent=2)
"
echo "✓ 已禁用。如需重新启用，运行 /auto-git-commit:init"
```

If the user says "completely remove":

```bash
rm .claude/auto-commit.json
echo "✓ .claude/auto-commit.json 已删除。"
```

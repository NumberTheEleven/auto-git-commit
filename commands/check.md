---
description: 安全扫描待提交文件，检测 API key、密码等敏感信息，支持白名单管理
allowed-tools: Bash(cat:*), Bash(echo:*), Bash(grep:*), Bash(git:*), Bash(python:*), Bash(find:*), Bash(head:*), Bash(ls:*), Bash(mkdir:*), Bash(date:*)
---

## Overview

Scan staged, unstaged, and untracked files for hardcoded secrets (API keys, passwords, tokens, private keys). For each finding, offer three actions: mark as dangerous (fix it), whitelist (false positive), or skip.

## Step 1: Collect changed files

```bash
echo "=== 安全扫描 ==="
echo ""

# Collect all changed files
FILES=$( {
  git diff --cached --name-only 2>/dev/null
  git diff --name-only 2>/dev/null
  git ls-files --others --exclude-standard 2>/dev/null | head -100
} | sort -u)

if [ -z "$FILES" ]; then
    echo "✓ 没有待提交的文件变更。"
    exit 0
fi

echo "待扫描文件:"
echo "$FILES" | head -20
FILE_COUNT=$(echo "$FILES" | wc -l)
if [ "$FILE_COUNT" -gt 20 ]; then
    echo "... 共 $FILE_COUNT 个文件"
fi
echo ""
```

## Step 2: Load existing exceptions

```bash
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
EXCEPTIONS=""
if [ -f "$PROJECT_ROOT/.claude/auto-commit.json" ]; then
    EXCEPTIONS=$(python -c "
import json
PROJECT_ROOT = '$PROJECT_ROOT'
with open(PROJECT_ROOT + '/.claude/auto-commit.json') as f:
    data = json.load(f)
for e in data.get('security', {}).get('exceptions', []):
    print(e.get('pattern', ''))
" 2>/dev/null || echo "")
fi
```

## Step 3: Scan each file

High-severity patterns to scan for:
1. `sk-[a-z0-9]{32,}` — OpenAI / Anthropic API key
2. `-----BEGIN .*PRIVATE KEY-----` — SSH / RSA private key
3. `(password|passwd|secret|token)\s*=\s*["'][^"']{8,}["']` — Hardcoded credentials
4. `ghp_[a-zA-Z0-9]{36}` — GitHub personal access token
5. `xox[baprs]-[a-zA-Z0-9-]+` — Slack token

Medium-severity patterns:
1. `jdbc:[a-z]+://[^/]+` — JDBC connection string
2. `(api[_-]?key|api[_-]?secret)\s*=\s*["'][^"']+["']` — API key assignment
3. `mongodb(\+srv)?://[^/]+` — MongoDB connection string
4. `(AKIA|ASIA)[A-Z0-9]{16}` — AWS access key

Scan approach: for each file, grep for each pattern. Filter out matches already in the exceptions list. Use the Read tool to show context around each match.

**For each new finding, present to the user:**

Display:
```
[file]:[line] 发现疑似 [type]: "[masked snippet]"
```

Show 3 lines of context (the matching line + line before and after).

Ask the user:
> "这个是不是真正的敏感信息？"
>
> **1. 是，帮我处理** — 指导替换为环境变量 / 加入 .gitignore
> **2. 误判，加入白名单** — 写入 exceptions，以后不再报警
> **3. 跳过** — 本次忽略，下次还会提醒

## Step 4: Handle user's choice

**If choice = 1 (dangerous):**
- If it's an API key pattern → suggest: `export API_KEY=xxx` + `process.env.API_KEY`
- Offer to add the file to `.gitignore` if the file is a config file
- Do NOT modify files automatically; explain what the user should do

**If choice = 2 (false positive):**
```bash
python -c "
import json, datetime
PROJECT_ROOT = '$(git rev-parse --show-toplevel 2>/dev/null || echo ".")'
with open(PROJECT_ROOT + '/.claude/auto-commit.json', 'r') as f:
    data = json.load(f)
data['security']['exceptions'].append({
    'file': '<filename>',
    'line': <line_number>,
    'pattern': '<matched_pattern>',
    'reason': '<user-provided reason>',
    'confirmedAt': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
})
with open(PROJECT_ROOT + '/.claude/auto-commit.json', 'w') as f:
    json.dump(data, f, indent=2)
"
echo "✓ 已加入白名单，以后不再提醒"
```

**If choice = 3 (skip):**
```
○ 已跳过。下次扫描还会出现，届时再处理。
```

## Step 5: Manage exceptions (optional)

If no new findings were found, offer to manage existing whitelist entries:

> "没有发现新的安全问题。当前白名单有 N 条记录。是否需要管理已有白名单？[Y/n]"

If yes, list each exception with its index and ask if the user wants to delete any:

```
白名单条目：
[0] config.py:12 — password=test123 (测试用假密码)
[1] .env.example:5 — api_key=sk-demo-key (示例key)

输入要删除的编号（多个用空格分隔），或按 Enter 跳过：
```

```bash
# User provides indices to delete, e.g. "0 2"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
INDICES_TO_REMOVE="<user-input-indices>"
python -c "
import json
indices = sorted([int(x) for x in '$INDICES_TO_REMOVE'.split()], reverse=True)
with open('$PROJECT_ROOT/.claude/auto-commit.json', 'r') as f:
    data = json.load(f)
exceptions = data.get('security', {}).get('exceptions', [])
for i in indices:
    if 0 <= i < len(exceptions):
        removed = exceptions.pop(i)
        print(f'已删除: {removed.get(\"file\", \"?\")} — {removed.get(\"pattern\", \"?\")[:50]}')
with open('$PROJECT_ROOT/.claude/auto-commit.json', 'w') as f:
    json.dump(data, f, indent=2)
"
```

## Step 6: Summary

```
echo ""
echo "============================================"
echo "  安全扫描完成"
echo "============================================"
if [ <had-findings> ]; then
    echo "  已处理: N 项"
    echo "  已加入白名单: N 项"
    echo "  已跳过: N 项"
fi
echo "  当前白名单条目数: N"
echo ""
```

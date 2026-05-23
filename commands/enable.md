---
description: 启用全局自动 git 提交（一次性设置）
allowed-tools: Bash(mkdir:*), Bash(cp:*), Bash(chmod:*), Bash(cat:*), Bash(echo:*), Bash(find:*), Bash(grep:*), Bash(python:*)
---

将 Stop hook 配置和 auto-commit.sh 部署到 ~/.claude/ 全局目录，一次性设置，幂等。

## Step 1: Locate and copy the hook script

```bash
PLUGIN_SCRIPT=$(find ~/.claude/plugins/cache -path "*auto-git-commit*/hooks/auto-commit.sh" | sort -r | head -1)
if [ -z "$PLUGIN_SCRIPT" ]; then
    echo "错误: 找不到 auto-commit.sh，请确认插件已安装。"
    exit 1
fi
mkdir -p ~/.claude/hooks
cp "$PLUGIN_SCRIPT" ~/.claude/hooks/auto-commit.sh
chmod +x ~/.claude/hooks/auto-commit.sh
if ! command -v claude &>/dev/null; then
    echo "警告: claude CLI 未安装，commit message 生成将降级为时间戳格式。"
fi
echo "脚本已部署到 ~/.claude/hooks/auto-commit.sh"
```

## Step 2: Register Stop hook (idempotent)

```bash
HOOK_FILE=~/.claude/settings.json

if [ ! -f "$HOOK_FILE" ]; then
    echo '{ "hooks": { "Stop": [ { "command": "bash ~/.claude/hooks/auto-commit.sh" } ] } }' > "$HOOK_FILE"
    echo "settings.json 已创建并注册 Stop hook"
elif grep -q "auto-commit.sh" "$HOOK_FILE" 2>/dev/null; then
    echo "Stop hook 已存在，跳过注册"
else
    python -c "
import json
try:
    with open('$HOOK_FILE', 'r') as f:
        data = json.load(f)
    if 'hooks' not in data:
        data['hooks'] = {}
    if 'Stop' not in data['hooks']:
        data['hooks']['Stop'] = []
    already = any('auto-commit.sh' in h.get('command', '') for h in data['hooks']['Stop'])
    if not already:
        data['hooks']['Stop'].append({'command': 'bash ~/.claude/hooks/auto-commit.sh'})
    with open('$HOOK_FILE', 'w') as f:
        json.dump(data, f, indent=2)
except json.JSONDecodeError:
    print('错误: ~/.claude/settings.json 格式异常，请手动检查。')
    import sys; sys.exit(1)
"
    echo "Stop hook 已注册到 settings.json"
fi
```

## Step 3: Verify

```bash
if [ -x ~/.claude/hooks/auto-commit.sh ]; then
    echo "脚本可执行 ✓"
else
    echo "错误: 脚本不可执行"
    exit 1
fi

if grep -q "auto-commit.sh" ~/.claude/settings.json 2>/dev/null; then
    echo "Hook 已注册 ✓"
else
    echo "错误: Hook 未注册"
    exit 1
fi

echo ""
echo "auto-git-commit 已全局启用。之后每次会话结束会自动检测变更、提交、推送。"

echo ""
echo "============================================"
echo "  auto-git-commit v2 全局设置完成！"
echo "============================================"
echo ""
echo "  接下来，对每个需要自动提交的项目运行："
echo "    /auto-git-commit:init"
echo ""
echo "  这将初始化项目的 git 仓库、配置远端、进行安全扫描。"
echo ""
echo "  其他命令："
echo "    /auto-git-commit:status   查看状态"
echo "    /auto-git-commit:check    安全扫描"
echo "    /auto-git-commit:disable  暂停自动提交"
```

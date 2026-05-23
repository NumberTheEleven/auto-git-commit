# auto-git-commit v2 待处理事项

## 安全

- [x] **exception whitelist 缺少管理命令** → 后续版本考虑
- [x] **check.md confirmedAt 存储的是字面量字符串** → 已修复为 Python datetime
- [x] **init 首次提交把项目文件内容发给 AI 生成 message 未在 README 披露** → 已添加隐私说明

## 基础设施

- [x] **plugin.json 未声明 hooks** → 已添加 hooks 声明
- [x] **没有 re-enable 命令** → disable 命令现在提示用户直接改 enabled 字段或运行 enable
- [ ] **Python 依赖过重** — 读取 JSON boolean / 简单字段可用 grep/sed 替代，减少依赖
- [x] **789 个 .in_use/ 锁文件泄漏** → 已清理并添加 .gitignore

## 体验

- [x] **没有日志文件** → 已添加 `~/.claude/logs/auto-git-commit.log`
- [x] **没有 dry-run 模式** → 已集成到 status 命令，显示待提交文件清单
- [x] **commit 语言不可配置** → 已添加 `language` 配置项（zh/en），hook 根据配置切换中英文
- [ ] **`git add -A` 无警告** — 会暂存所有文件（含 untracked），用户可能意外提交不想提交的文件
- [ ] **no commit signing** — 缺少 GPG 签名 / --signoff 支持
- [ ] **config 文件不能手动编辑** — 缺少 `--edit` 命令打开配置文件
- [x] **ANSI 颜色码未做 TTY 检测** → 已添加 `[ -t 1 ]` 检测，非终端时不输出颜色

## 健壮性

- [x] **git push timeout 硬编码 60 秒** → 已改为从 config 读取 `pushTimeout`，默认 60 秒
- [ ] **错误信息 grep 模式依赖英文 Git 输出** — 非英文 locale 的 Git 可能匹配不到
- [x] **`git pull --rebase` 不指定 origin/branch** → 已修复为 `git pull --rebase origin "$BRANCH"`
- [x] **空 commit 场景未友好提示** → 已添加检测 "nothing to commit" 并优雅退出
- [ ] **init.md 项目信息收集 (`head -50`) 可能包含敏感内容发给 AI**
- [x] **`datetime.utcnow()` 在 Python 3.12+ 已废弃** → init.md 和 check.md 已更新为 `datetime.now(datetime.timezone.utc)`
- [x] **init.md 配置 createdAt 用 UTC，commit message fallback 用本地时间** → 统一为 UTC（Python 用 timezone.utc，shell 用 date 本地时间用于显示）

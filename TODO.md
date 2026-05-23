# auto-git-commit v2 待处理事项

## 剩余条目（优先级从高到低）

### 待处理

- [ ] **Python 依赖过重** — 读取 JSON boolean / 简单字段可用 grep/sed 替代，减少对 Python 的依赖
- [ ] **git add -A 无警告** — 会暂存所有文件（含 untracked），用户可能意外提交不想提交的文件
- [ ] **no commit signing** — 缺少 GPG 签名 / --signoff 支持
- [ ] **config 文件管理命令** — 缺少 `--edit` 命令打开配置文件；白名单无法查看/删除
- [ ] **错误信息 grep 模式依赖英文 Git 输出** — 非英文 locale 的 Git 可能匹配不到
- [ ] **init.md 项目信息收集 (`head -50`) 可能包含敏感内容发给 AI**

### 已完成

- [x] check.md confirmedAt 字面量字符串 bug → Python datetime
- [x] README 隐私说明
- [x] plugin.json hooks 声明
- [x] re-enable 路径 → disable 提示用户改 enabled 字段
- [x] 789 个 .in_use/ 锁文件 → 已清理 + .gitignore
- [x] 日志文件 `~/.claude/logs/auto-git-commit.log`
- [x] dry-run 模式 → 集成到 status 命令
- [x] commit 语言可配置 → config 添加 language 字段（zh/en）
- [x] ANSI 颜色码 TTY 检测
- [x] push timeout 可配置 → config 添加 pushTimeout 字段
- [x] git pull --rebase 指定 origin/branch
- [x] 空 commit 友好提示 → 检测 "nothing to commit" 退出
- [x] datetime.utcnow() 废弃 → datetime.now(datetime.timezone.utc)
- [x] 时区一致性 → UTC
- [x] 配置路径一致性 → 统一 git rev-parse --show-toplevel
- [x] 安全扫描模式补齐 9 个（高危+中危）
- [x] 白名单 file 粒度匹配
- [x] REMOTE_URL 注入风险 → 环境变量传递

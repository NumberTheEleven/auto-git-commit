# auto-git-commit v2 待处理事项

## 安全

- [ ] **exception whitelist 缺少管理命令** — 只能通过 check 追加，无法查看/删除/更新已有白名单条目
- [ ] **check.md confirmedAt 存储的是字面量字符串 `$(date ...)` 而非实际日期** — 需改为在 Python 中生成时间戳
- [ ] **init 首次提交把项目文件内容发给 AI 生成 message 未在 README 披露** — 需加隐私说明

## 基础设施

- [ ] **plugin.json 未声明 hooks** — 导致卸载时 hook 配置残留 settings.json，需增加卸载/清理能力
- [ ] **没有 re-enable 命令** — disable 后只能重新 init，但 init 会覆盖整个配置文件，丢失已积累的白名单
- [ ] **Python 依赖过重** — 读取 JSON boolean / 简单字段可用 grep/sed 替代，减少依赖
- [ ] **789 个 .in_use/ 锁文件泄漏** — 每次会话创建一个锁文件但从不清理

## 体验

- [ ] **没有日志文件** — Stop hook 静默执行，stdout 在会话结束后不可见，排查问题困难
- [ ] **没有 dry-run 模式** — 无法预览即将提交的内容
- [ ] **commit 语言不可配置** — 目前固定中文，英文项目可能需要英文提交信息
- [ ] **`git add -A` 无警告** — 会暂存所有文件（含 untracked），用户可能意外提交不想提交的文件
- [ ] **no commit signing** — 缺少 GPG 签名 / --signoff 支持
- [ ] **config 文件不能手动编辑** — 缺少 `--edit` 命令打开配置文件
- [ ] **ANSI 颜色码未做 TTY 检测** — 重定向到文件时会写入颜色转义序列

## 健壮性

- [ ] **git push timeout 硬编码 60 秒** — 大仓库或慢网络可能不够，应可配置
- [ ] **错误信息 grep 模式依赖英文 Git 输出** — 非英文 locale 的 Git 可能匹配不到
- [ ] **`git pull --rebase` 不指定 origin/branch** — 多 remote 时可能从错误远端拉取
- [ ] **空 commit 场景未友好提示** — Gate 3 到实际 commit 之间有竞态窗口
- [ ] **init.md 项目信息收集 (`head -50`) 可能包含敏感内容发给 AI**
- [ ] **`datetime.utcnow()` 在 Python 3.12+ 已废弃** — 状态和检查命令中可能仍在使用
- [ ] **init.md 配置 createdAt 用 UTC，commit message fallback 用本地时间** — 时区不一致

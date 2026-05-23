# auto-git-commit v2

Claude Code 会话结束时自动检测文件变更，AI 生成 commit message 并 commit + push 到 GitHub。

## 安装

```
/plugin marketplace add https://github.com/NumberTheEleven/eleven-marketplace
/plugin install auto-git-commit@eleven-marketplace
/auto-git-commit:enable
```

## 使用

```
/auto-git-commit:enable     全局一次性设置
/auto-git-commit:init       初始化当前项目（git init + remote + 首次提交）
/auto-git-commit:check      安全扫描（检测 API key、密码等敏感信息）
/auto-git-commit:status     查看状态
/auto-git-commit:disable    暂停当前项目自动提交
```

## 功能

- **有变更**: AI 分析 diff，生成 conventional commit message → commit → push
- **安全扫描**: 提交前检测硬编码凭据，高危命中阻止提交，支持白名单管理
- **push 重试**: 远端冲突时自动 pull --rebase 后重试
- **错误区分**: 无 remote / 认证失败 / 冲突 / 网络，各给出具体指引
- **项目级控制**: 通过 `.claude/auto-commit.json` 按项目启用/禁用

## 依赖

- git
- claude CLI（可选，AI 生成 commit message 需要）
- gh CLI（可选，自动创建 GitHub 仓库需要）

## 安全扫描规则

| 级别 | 模式 | 说明 |
|------|------|------|
| 高危 | `sk-...` | OpenAI / Anthropic API key |
| 高危 | `-----BEGIN ... PRIVATE KEY-----` | SSH / RSA 私钥 |
| 高危 | `password=...` / `secret=...` | 硬编码凭据 |
| 高危 | `ghp_...` | GitHub personal access token |
| 高危 | `xox...` | Slack token |
| 中危 | `jdbc://...` | 数据库连接串 |
| 中危 | `api_key=...` | API key 赋值 |

## 作者

NumberTheEleven

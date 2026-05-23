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

- **有变更**: AI 分析 diff，生成中文 conventional commit message → commit → push
- **安全扫描**: 提交前检测硬编码凭据，命中阻止提交，支持白名单管理
- **push 重试**: 远端冲突时自动 pull --rebase 后重试，冲突自动回滚
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
| 中危 | `api_key=...` / `api_secret=...` | API key 赋值 |
| 中危 | `mongodb://...` / `mongodb+srv://...` | MongoDB 连接串 |
| 中危 | `AKIA...` / `ASIA...` | AWS access key |

## 配置文件

```json
// .claude/auto-commit.json
{
  "enabled": true,
  "createdAt": "2026-05-23T05:56:55Z",
  "remote": {
    "type": "github",
    "url": "https://github.com/user/repo.git"
  },
  "security": {
    "exceptions": [
      {
        "file": "config.py",
        "line": 12,
        "pattern": "password=test123",
        "reason": "测试用假密码",
        "confirmedAt": "2026-05-23T06:00:00Z"
      }
    ]
  }
}
```

## 隐私说明

- init 和 hook 在生成 commit message 时，会将 git diff 内容发送给 Claude API。请确保项目中不包含不应发送到外部服务的敏感信息。
- 安全扫描在本地执行，不会将扫描内容发送到外部。
- 所有提交和推送操作均在本地执行，使用您本机的 git 和 GitHub 凭据。

## 常见问题

**Q: 会话结束了没提交？**
检查项目是否已接入：`/auto-git-commit:status`。确保 `.claude/auto-commit.json` 中的 `enabled` 为 `true`。

**Q: push 失败？**
- 认证错误：运行 `gh auth login` 重新登录
- 无 remote：运行 `/auto-git-commit:init` 配置远端
- 冲突：手动 `git pull --rebase` 后 `git push`

**Q: 安全扫描误判？**
运行 `/auto-git-commit:check`，将误判项加入白名单。

**Q: 想禁用某个项目？**
运行 `/auto-git-commit:disable`。

## 作者

NumberTheEleven

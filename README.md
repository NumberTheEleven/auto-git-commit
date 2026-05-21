# auto-git-commit

每次 Claude Code 会话结束时自动检测文件变更，AI 归纳 commit message 并 commit + push 到 GitHub。

## 安装

```
/plugin marketplace add https://github.com/NumberTheEleven/eleven-marketplace
/plugin install auto-git-commit@eleven-marketplace
/auto-git-commit:enable
```

之后所有项目的会话结束都会自动提交推送。

## 功能

- **有变更**: AI 分析 git diff，生成 conventional commit message，自动 commit + push
- **无变更**: 静默退出
- **非 git 目录**: 提示确认后 init + 创建 GitHub 仓库
- **push 失败**: 黄色警告，不阻断退出

## 依赖

- git
- claude CLI
- gh CLI（可选，非 git 目录初始化时需要）

## 作者

NumberTheEleven

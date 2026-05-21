#!/usr/bin/env bash
set -euo pipefail

YELLOW='\033[1;33m'
NC='\033[0m'

# ── Check git is available
if ! command -v git &>/dev/null; then
    echo "错误: git 未安装，请先安装 git。"
    exit 1
fi

# ── Function: generate commit message via AI or fallback
generate_message() {
    local diff_content="$1"
    local msg

    msg=$(claude -p \
        "Based on the following git diff, generate a single-line conventional commit message in English (e.g. 'feat:', 'fix:', 'refactor:', 'chore:', 'docs:'). Return ONLY the commit message, nothing else. Diff:

$diff_content" 2>/dev/null) || true

    if [ -z "${msg//[[:space:]]/}" ]; then
        msg="auto: update $(date '+%Y-%m-%d %H:%M')"
    fi

    echo "$msg"
}

# ── Function: generate init commit message from project structure
generate_init_message() {
    local project_info
    project_info="Project structure:"$'\n'"$(ls -laR 2>/dev/null | head -150)"$'\n'

    # Collect key config files
    for f in package.json README.md Makefile pyproject.toml go.mod Cargo.toml docker-compose.yml Dockerfile; do
        if [ -f "$f" ]; then
            project_info="$project_info"$'\n'"=== $f ==="$'\n'"$(head -50 "$f")"$'\n'
        fi
    done

    local msg
    msg=$(claude -p \
        "Based on the following project information, generate a single-line init commit message in English (e.g. 'init: React + TypeScript blog platform'). Return ONLY the commit message, nothing else.

$project_info" 2>/dev/null) || true

    if [ -z "${msg//[[:space:]]/}" ]; then
        msg="init: project setup $(date '+%Y-%m-%d')"
    fi

    echo "$msg"
}

# ── Function: find gh binary (including post-install paths)
find_gh() {
    if command -v gh &>/dev/null; then
        command -v gh
        return 0
    fi
    # Common post-install paths on Windows (winget/choco), not yet in PATH
    for candidate in "/c/Program Files/GitHub CLI/gh.exe" "/c/Program Files (x86)/GitHub CLI/gh.exe"; do
        if [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

# ── Function: detect package manager and install gh CLI
install_gh() {
    if command -v winget &>/dev/null; then
        winget install --id GitHub.cli --silent
    elif command -v choco &>/dev/null; then
        choco install gh -y
    elif command -v brew &>/dev/null; then
        brew install gh
    elif command -v apt-get &>/dev/null; then
        echo "请先安装 gh CLI。参考: https://github.com/cli/cli/blob/trunk/docs/install_linux.md"
        return 1
    else
        echo "无法自动检测包管理器，请手动安装 gh CLI: https://cli.github.com"
        return 1
    fi
}

# ── Function: setup GitHub remote
setup_remote() {
    local gh_cmd
    if gh_cmd=$(find_gh); then
        if ! "$gh_cmd" auth status &>/dev/null; then
            echo "gh CLI 未登录，请运行 'gh auth login' 后再试。"
            echo -n "请输入 GitHub 仓库 URL (如 https://github.com/user/repo.git): "
            read -r url || true
            if [ -n "$url" ]; then
                if git remote get-url origin &>/dev/null; then
                    git remote set-url origin "$url"
                else
                    git remote add origin "$url"
                fi
                git push -u origin main
            else
                echo "未提供 URL，跳过 push。commit 已保存在本地。"
            fi
            return
        fi
        "$gh_cmd" repo create "$(basename "$(pwd)")" --private --source=. --remote=origin --push
    else
        echo -n "gh CLI 未安装，是否自动安装？[Y/n] "
        read -r answer || true
        if [ -z "$answer" ] || [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
            if install_gh; then
                if gh_cmd=$(find_gh); then
                    "$gh_cmd" repo create "$(basename "$(pwd)")" --private --source=. --remote=origin --push
                    return
                fi
            fi
            echo -n "请输入 GitHub 仓库 URL (如 https://github.com/user/repo.git): "
            read -r url || true
            if [ -n "$url" ]; then
                if git remote get-url origin &>/dev/null; then
                    git remote set-url origin "$url"
                else
                    git remote add origin "$url"
                fi
                git push -u origin main
            else
                echo "未提供 URL，跳过 push。commit 已保存在本地。"
            fi
        else
            echo -n "请输入 GitHub 仓库 URL (如 https://github.com/user/repo.git): "
            read -r url || true
            if [ -n "$url" ]; then
                if git remote get-url origin &>/dev/null; then
                    git remote set-url origin "$url"
                else
                    git remote add origin "$url"
                fi
                git push -u origin main
            else
                echo "未提供 URL，跳过 push。commit 已保存在本地。"
            fi
        fi
    fi
}

# ═══════════════════════════════════════════════
# Main flow
# ═══════════════════════════════════════════════

if git rev-parse --git-dir &>/dev/null; then
    # ── Existing git repo ──
    if [ -z "$(git status --porcelain)" ]; then
        exit 0
    fi

    untracked_content=""
    count=0
    while IFS= read -r -d '' file; do
        count=$((count + 1))
        if [ "$count" -gt 50 ]; then
            untracked_content="$untracked_content... (truncated, $count untracked files total)\n"
            break
        fi
        if grep -Iq . "$file" 2>/dev/null; then
            untracked_content="$untracked_content=== new file: $file ===\n$(cat -- "$file" 2>/dev/null)\n"
        else
            untracked_content="$untracked_content=== new file: $file === (binary, skipped)\n"
        fi
    done < <(git ls-files --others --exclude-standard -z 2>/dev/null)
    diff_content="$(git diff --cached 2>/dev/null)
    $(git diff 2>/dev/null)
    $untracked_content"
    msg=$(generate_message "$diff_content")

    git add -A
    git commit -m "$msg"

    if git push 2>&1; then
        :
    else
        echo -e "${YELLOW}⚠ git push 失败，请手动检查。commit 已保存在本地。${NC}"
    fi

else
    # ── Not a git repo ──
    echo -n "当前目录非 git 仓库，是否初始化并上传到 GitHub？[Y/n] "
    read -r answer || true

    if [ -z "$answer" ] || [ "$answer" = "Y" ] || [ "$answer" = "y" ]; then
        msg=$(generate_init_message)

        git init
        git add -A
        git commit -m "$msg"
        git branch -M main

        setup_remote
    fi
fi

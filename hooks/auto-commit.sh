#!/usr/bin/env bash
set -euo pipefail

# ── Color helpers (only emit when stdout is a terminal) ──
if [ -t 1 ]; then
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    NC='\033[0m'
else
    YELLOW=''; RED=''; GREEN=''; NC=''
fi

# ── Log file ──
LOG_DIR="$HOME/.claude/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/auto-git-commit.log"
log() {
    local level="$1"; shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" >> "$LOG_FILE"
}

# ── Find project root (where .git is) ──
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
if [ -n "$PROJECT_ROOT" ]; then
    CONFIG_FILE="$PROJECT_ROOT/.claude/auto-commit.json"
else
    CONFIG_FILE=".claude/auto-commit.json"
fi
log INFO "Stop hook triggered, config=$CONFIG_FILE"

# ═══════════════════════════════════════════════
# Gate 1: Project-level opt-in
# ═══════════════════════════════════════════════
if [ ! -f "$CONFIG_FILE" ]; then
    log INFO "Gate 1: no config file, silent exit"
    exit 0
fi

# Check enabled flag (grep for false: default is enabled)
if grep -q '"enabled": *false' "$CONFIG_FILE" 2>/dev/null; then
    log INFO "Gate 1: config disabled, exit"
    exit 0
fi

# Load language preference (default: zh)
LANG_PREF=$(grep '"language"' "$CONFIG_FILE" 2>/dev/null | sed 's/.*"language": *"\([^"]*\)".*/\1/' || echo "")
[ -z "$LANG_PREF" ] && LANG_PREF="zh"

# ═══════════════════════════════════════════════
# Gate 2: Must be a git repo
# ═══════════════════════════════════════════════
if ! git rev-parse --git-dir &>/dev/null; then
    log INFO "Gate 2: not a git repo, exit"
    echo -e "${YELLOW}[auto-git-commit] 当前目录不是 git 仓库。${NC}"
    echo "  运行 /auto-git-commit:init 初始化并接入自动提交。"
    exit 0
fi

# ═══════════════════════════════════════════════
# Gate 3: Must have changes
# ═══════════════════════════════════════════════
if [ -z "$(git status --porcelain)" ]; then
    log INFO "Gate 3: no changes, silent exit"
    exit 0
fi

# ═══════════════════════════════════════════════
# Gate 4: Check for remote (warn but allow local commit)
# ═══════════════════════════════════════════════
HAS_REMOTE=true
if ! git remote get-url origin &>/dev/null; then
    HAS_REMOTE=false
fi

# ═══════════════════════════════════════════════
# Security scanning
# ═══════════════════════════════════════════════

# Load exceptions from config
# Returns "file::pattern" per line (empty file field = global exception)
load_exceptions() {
    local records=""
    if [ -f "$CONFIG_FILE" ]; then
        records=$(python -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
exceptions = data.get('security', {}).get('exceptions', [])
for e in exceptions:
    f = e.get('file', '')
    p = e.get('pattern', '')
    print(f + '::' + p)
" 2>/dev/null || echo "")
    fi
    echo "$records"
}

# Scan staged + unstaged + untracked files for secrets
scan_secrets() {
    local exceptions
    exceptions=$(load_exceptions)

    # Combined security patterns for single grep pass (high + medium severity)
    local combined_pattern='(sk-[a-z0-9]{32,}|-----BEGIN .*PRIVATE KEY-----|(password|passwd|secret|token)\s*=\s*["'"'"'][^"'"'"']{8,}["'"'"']|ghp_[a-zA-Z0-9]{36}|xox[baprs]-[a-zA-Z0-9-]+|jdbc:[a-z]+://[^/]+|(api[_-]?key|api[_-]?secret)\s*=\s*["'"'"'][^"'"'"']+["'"'"']|mongodb(\+srv)?://[^/]+|(AKIA|ASIA)[A-Z0-9]{16})'

    local found_any=false

    # Get list of changed files (including untracked)
    while IFS= read -r file; do
        if [ -z "$file" ]; then continue; fi
        # Skip binary files
        if ! grep -Iq . "$file" 2>/dev/null; then continue; fi

        # Use grep -n directly on file — avoids echo|grep per-line hang on Windows
        local matches
        matches=$(grep -nE "$combined_pattern" "$file" 2>/dev/null) || true
        if [ -z "$matches" ]; then continue; fi

        while IFS= read -r match_line; do
            if [ -z "$match_line" ]; then continue; fi
            local line_num="${match_line%%:*}"
            local content="${match_line#*:}"
            local snippet="${content:0:80}"

            # Check exception whitelist (respects file scope)
            local is_exception=false
            if [ -n "$exceptions" ]; then
                while IFS= read -r exc; do
                    if [ -z "$exc" ]; then continue; fi
                    local exc_file="${exc%%::*}"
                    local exc_pattern="${exc#*::}"
                    # Exception matches if: (no file scope OR file matches) AND pattern matches content
                    if [ -n "$exc_pattern" ] && echo "$content" | grep -qF "$exc_pattern" 2>/dev/null; then
                        if [ -z "$exc_file" ] || [ "$exc_file" = "$file" ]; then
                            is_exception=true
                            break
                        fi
                    fi
                done <<< "$exceptions"
            fi

            if [ "$is_exception" = false ]; then
                echo "  $file:$line_num: $snippet"
                found_any=true
            fi
        done <<< "$matches"
    done < <(git diff --cached --name-only 2>/dev/null; git diff --name-only 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null | head -100)

    if [ "$found_any" = true ]; then
        return 1
    fi
    return 0
}

# ═══════════════════════════════════════════════
# Gate 5: Security scan before commit
# ═══════════════════════════════════════════════
SECURITY_ISSUES=$(scan_secrets)
if [ $? -ne 0 ]; then
    log WARN "security scan found issues, blocking commit"
    echo -e "${RED}[auto-git-commit] 发现疑似敏感信息，提交已阻止。${NC}"
    echo "$SECURITY_ISSUES"
    echo ""
    echo "  如果是误判，运行 /auto-git-commit:check 逐项确认并加入白名单。"
    echo "  如果确实危险，请立即处理（替换为环境变量 / 加入 .gitignore）。"
    exit 0
fi
log INFO "security scan passed"

# ═══════════════════════════════════════════════
# Commit message generation
# ═══════════════════════════════════════════════

generate_message() {
    local msg

    # Collect untracked file content for context (up to 50 files)
    local untracked_content=""
    local count=0
    while IFS= read -r -d '' file; do
        count=$((count + 1))
        if [ "$count" -gt 50 ]; then
            untracked_content="$untracked_content... (truncated, $count untracked files total)\n"
            break
        fi
        if grep -Iq . "$file" 2>/dev/null; then
            untracked_content="$untracked_content=== new file: $file ===\n$(cat -- "$file" 2>/dev/null)\n"
        fi
    done < <(git ls-files --others --exclude-standard -z 2>/dev/null)

    local full_diff
    full_diff="$(git diff --cached 2>/dev/null)
$(git diff 2>/dev/null)
$untracked_content"

    if command -v claude &>/dev/null; then
        if [ "$LANG_PREF" = "en" ]; then
            msg=$(timeout 30 claude -p \
"Based on the following git diff, generate a single-line conventional commit message in English (e.g. 'feat: add user login', 'fix: resolve cache expiration', 'refactor: restructure router', 'chore: update deps', 'docs: add API guide'). Return ONLY the commit message, nothing else. Diff:

$full_diff" 2>/dev/null) || true
        else
            msg=$(timeout 30 claude -p \
"根据以下 git diff，用中文生成一行中文提交信息，使用中文类型前缀（如 '新增: 用户登录功能'、'修复: 缓存过期问题'、'重构: 路由模块'、'杂项: 更新依赖版本'、'文档: 补充API说明'）。只返回提交信息，不要其他内容。Diff:

$full_diff" 2>/dev/null) || true
        fi
    fi

    if [ -z "${msg//[[:space:]]/}" ]; then
        if [ "$LANG_PREF" = "en" ]; then
            msg="chore: auto commit $(date '+%Y-%m-%d %H:%M')"
        else
            msg="杂项: 自动提交 $(date '+%Y-%m-%d %H:%M')"
        fi
    fi

    echo "$msg"
}

# ═══════════════════════════════════════════════
# Execute commit
# ═══════════════════════════════════════════════

msg=$(generate_message)

# Show what will be committed
STAGED_COUNT=$(git diff --cached --name-only 2>/dev/null | wc -l)
MODIFIED_COUNT=$(git diff --name-only 2>/dev/null | wc -l)
UNTRACKED_COUNT=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)
TOTAL=$((STAGED_COUNT + MODIFIED_COUNT + UNTRACKED_COUNT))
log INFO "staging $TOTAL files (staged:$STAGED_COUNT modified:$MODIFIED_COUNT untracked:$UNTRACKED_COUNT)"

git add -A

# Detect commit signing preference
COMMIT_FLAGS="-m"
if git config --bool commit.gpgsign &>/dev/null; then
    COMMIT_FLAGS="-S -m"
fi

COMMIT_OUTPUT=$(git commit $COMMIT_FLAGS "$msg" 2>&1) || true
if echo "$COMMIT_OUTPUT" | grep -q "nothing to commit"; then
    log INFO "nothing to commit (race), exiting"
    exit 0
fi
log INFO "committed: $msg"

# Load push timeout from config (default 60 seconds)
PUSH_TIMEOUT=$(grep '"pushTimeout"' "$CONFIG_FILE" 2>/dev/null | grep -o '[0-9]\+' || echo "60")
log INFO "push timeout: ${PUSH_TIMEOUT}s"

# ═══════════════════════════════════════════════
# Push with error differentiation and retry
# ═══════════════════════════════════════════════

PUSH_OUTPUT=$(timeout "$PUSH_TIMEOUT" git push 2>&1) && PUSH_OK=true || PUSH_OK=false

if [ "$PUSH_OK" = true ]; then
    log INFO "push succeeded: $msg"
    echo -e "${GREEN}[auto-git-commit] 已提交并推送: $msg${NC}"
    exit 0
fi

# ── No remote ──
if echo "$PUSH_OUTPUT" | grep -qiE "No such remote|remote not found|does not appear to be a git repository|fatal: 'origin'"; then
    log WARN "no remote configured"
    echo -e "${YELLOW}[auto-git-commit] 已本地提交，但未配置远端仓库。${NC}"
    echo "  运行 /auto-git-commit:init 配置远端。"
    exit 0
fi

# ── No upstream tracking ──
if echo "$PUSH_OUTPUT" | grep -qiE "no upstream branch|has no upstream"; then
    BRANCH=$(git branch --show-current)
    PUSH_OUTPUT2=$(timeout "$PUSH_TIMEOUT" git push -u origin "$BRANCH" 2>&1) && PUSH_OK2=true || PUSH_OK2=false
    if [ "$PUSH_OK2" = true ]; then
        echo -e "${GREEN}[auto-git-commit] 已提交并推送: $msg${NC}"
        exit 0
    fi
    PUSH_OUTPUT="$PUSH_OUTPUT2"
fi

# ── Authentication failure ──
if echo "$PUSH_OUTPUT" | grep -qiE "403|401|Authentication failed|access denied|permission denied|not authorized|fatal: Authentication"; then
    log WARN "push auth failure"
    echo -e "${RED}[auto-git-commit] 推送失败：认证错误。${NC}"
    echo "  运行 'gh auth login' 重新登录。commit 已保存在本地。"
    exit 0
fi

# ── Non-fast-forward (try rebase) ──
if echo "$PUSH_OUTPUT" | grep -qiE "non-fast-forward|\[rejected\]|fetch first"; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "main")
    REBASE_OUTPUT=$(git pull --rebase origin "$BRANCH" 2>&1) || true
    if echo "$REBASE_OUTPUT" | grep -qiE "CONFLICT|conflict|error:|fatal:"; then
        git rebase --abort 2>/dev/null || true
        log WARN "rebase conflict detected, aborted"
        echo -e "${RED}[auto-git-commit] 推送失败：rebase 过程中出现冲突。${NC}"
        echo "  冲突已回滚，commit 已保存在本地。请手动处理："
        echo "    git pull --rebase origin $BRANCH"
        echo "    git push"
        exit 0
    fi
    PUSH_OUTPUT3=$(timeout "$PUSH_TIMEOUT" git push 2>&1) && PUSH_OK3=true || PUSH_OK3=false
    if [ "$PUSH_OK3" = true ]; then
        log INFO "push succeeded after rebase"
        echo -e "${GREEN}[auto-git-commit] 已提交并推送（rebase 后成功）: $msg${NC}"
        exit 0
    fi
    log ERROR "push failed after rebase"
    echo -e "${RED}[auto-git-commit] 推送失败：rebase 后仍无法推送。${NC}"
    echo "  请手动处理。commit 已保存在本地。"
    exit 0
fi

# ── Unknown error ──
log ERROR "push failed: $(echo "$PUSH_OUTPUT" | head -1)"
echo -e "${RED}[auto-git-commit] 推送失败：${NC}"
echo "$PUSH_OUTPUT" | head -5
echo ""
echo "  commit 已保存在本地。"
exit 0

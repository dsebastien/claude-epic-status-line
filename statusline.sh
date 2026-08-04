#!/usr/bin/env bash
# Claude Epic Status Line v2 — refined status line + rate-limit dashboard
#
# Data sources:
#   - Claude Code statusline stdin JSON (authoritative: model, context, cost,
#     git cwd, effort, badges, 5-hour/7-day rate limits)  [Claude Code >= 2.1.140]
#   - OAuth usage API (optional enrichment only: extra-usage credits and
#     per-model scoped weekly limits; skipped when no token is resolvable)
#
# Configuration (all optional):
#   defaults below  <  ~/.config/claude-epic-status-line/config.sh  <  CESL_* env vars
#
# Subcommand: `statusline.sh explain` (with the same stdin) dumps the received
# JSON and every parsed value instead of rendering — for debugging.
set -f
export LC_ALL=C

mode="${1:-}"
if [ -t 0 ]; then
    input=""
else
    input=$(head -c 1048576)
fi

if [ -z "$input" ] && [ "$mode" != "explain" ]; then
    printf "Claude"
    exit 0
fi

# jq is a hard requirement; without it every parse below would silently
# misrender (fake 0% quota rows) — degrade to a static line instead.
if ! command -v jq >/dev/null 2>&1; then
    printf "Claude"
    exit 0
fi

# ── Config layering: defaults < config file < environment ───────────
_cesl_env=$(export -p 2>/dev/null | grep '^declare -x CESL_' | sed 's/^declare -x /export /')
_cesl_cfg="${CESL_CONFIG:-$HOME/.config/claude-epic-status-line/config.sh}"
[ -f "$_cesl_cfg" ] && . "$_cesl_cfg"
[ -n "$_cesl_env" ] && eval "$_cesl_env" 2>/dev/null

# Escalation thresholds (single scale: dim < warn < high < crit)
: "${CESL_WARN:=70}"
: "${CESL_HIGH:=80}"
: "${CESL_CRIT:=90}"
# Session cost thresholds (in display currency)
: "${CESL_COST_WARN:=5}"
: "${CESL_COST_CRIT:=20}"
# Bars
: "${CESL_BAR_WIDTH:=10}"
# Usage API cache TTL (seconds)
: "${CESL_CACHE_TTL:=60}"
# Currency
: "${CESL_CURRENCY_SYMBOL:=$}"
: "${CESL_CURRENCY_RATE:=1}"
# Glyph set: unicode (default) | nerd | ascii
: "${CESL_GLYPHS:=unicode}"
# Segment toggles (1 = shown)
: "${CESL_SHOW_MODEL:=1}"
: "${CESL_SHOW_CONTEXT:=1}"
: "${CESL_SHOW_DIR:=1}"
: "${CESL_SHOW_GIT:=1}"
: "${CESL_SHOW_COST:=1}"
: "${CESL_SHOW_DURATION:=1}"
: "${CESL_SHOW_LINES:=1}"
: "${CESL_SHOW_EFFORT:=1}"
: "${CESL_SHOW_BADGES:=1}"
: "${CESL_SHOW_RATE_BLOCK:=1}"
# Palette (truecolor "R;G;B")
: "${CESL_COLOR_TEXT:=220;220;220}"
: "${CESL_COLOR_OK:=0;175;80}"
: "${CESL_COLOR_WARN:=230;200;0}"
: "${CESL_COLOR_HIGH:=255;176;85}"
: "${CESL_COLOR_CRIT:=255;85;85}"
: "${CESL_COLOR_DIR:=86;182;194}"
: "${CESL_COLOR_AGENT:=180;140;255}"
# Model-family hues (model name only)
: "${CESL_COLOR_OPUS:=180;140;255}"
: "${CESL_COLOR_SONNET:=0;153;255}"
: "${CESL_COLOR_HAIKU:=64;200;180}"
: "${CESL_COLOR_FABLE:=240;190;60}"
: "${CESL_COLOR_MODEL:=0;153;255}"

# Sanitize numeric knobs — a config typo must not break rendering
case "$CESL_WARN" in ''|*[!0-9]*) CESL_WARN=70 ;; esac
case "$CESL_HIGH" in ''|*[!0-9]*) CESL_HIGH=80 ;; esac
case "$CESL_CRIT" in ''|*[!0-9]*) CESL_CRIT=90 ;; esac
case "$CESL_BAR_WIDTH" in ''|0|*[!0-9]*) CESL_BAR_WIDTH=10 ;; esac
[ "${#CESL_BAR_WIDTH}" -gt 3 ] && CESL_BAR_WIDTH=10
CESL_BAR_WIDTH=$(( 10#$CESL_BAR_WIDTH ))
[ "$CESL_BAR_WIDTH" -eq 0 ] && CESL_BAR_WIDTH=10
[ "$CESL_BAR_WIDTH" -gt 200 ] && CESL_BAR_WIDTH=200
case "$CESL_CACHE_TTL" in ''|*[!0-9]*) CESL_CACHE_TTL=60 ;; esac
[ "${#CESL_CACHE_TTL}" -gt 7 ] && CESL_CACHE_TTL=60
CESL_WARN=$(( 10#$CESL_WARN )); CESL_HIGH=$(( 10#$CESL_HIGH )); CESL_CRIT=$(( 10#$CESL_CRIT ))

# ── Glyphs ──────────────────────────────────────────────────────────
case "$CESL_GLYPHS" in
    ascii)
        g_sep="|"  g_fill="#" g_empty="." g_warn="!" g_reset="~"
        g_dot="-"  g_ellipsis="..." g_ahead="^" g_behind="v" g_wt="wt"
        g_eff_high="*" g_eff_med="o" g_eff_low="." g_branch=""
        ;;
    nerd)
        g_sep="│"  g_fill="█" g_empty="░" g_warn="⚠" g_reset="⟳"
        g_dot="·"  g_ellipsis="…" g_ahead="⇡" g_behind="⇣" g_wt="⎇wt"
        g_eff_high="●" g_eff_med="◑" g_eff_low="◔" g_branch=" "
        ;;
    *)
        g_sep="│"  g_fill="█" g_empty="░" g_warn="⚠" g_reset="⟳"
        g_dot="·"  g_ellipsis="…" g_ahead="⇡" g_behind="⇣" g_wt="⎇wt"
        g_eff_high="●" g_eff_med="◑" g_eff_low="◔" g_branch=""
        ;;
esac

# ── ANSI ────────────────────────────────────────────────────────────
dim='\033[2m'
bold='\033[1m'
reset='\033[0m'
c_txt="\033[38;2;${CESL_COLOR_TEXT}m"
c_ok="\033[38;2;${CESL_COLOR_OK}m"
c_warn="\033[38;2;${CESL_COLOR_WARN}m"
c_high="\033[38;2;${CESL_COLOR_HIGH}m"
c_crit="\033[38;2;${CESL_COLOR_CRIT}m"
c_dir="\033[38;2;${CESL_COLOR_DIR}m"
c_agent="\033[38;2;${CESL_COLOR_AGENT}m"
alert="${bold}\033[38;2;${CESL_COLOR_CRIT}m"

sep=" ${dim}${g_sep}${reset} "
dot=" ${dim}${g_dot}${reset} "

# ── Helpers ─────────────────────────────────────────────────────────
# Strip control characters and neutralize backslashes in untrusted display
# strings — everything rendered goes through printf %b, which would otherwise
# decode escape sequences (terminal injection via branch names, paths, API
# labels, model names)
sanitize() { # string [max-length]
    local s
    s=$(printf '%s' "$1" | tr -d '\000-\037\177' | tr '\\' '/')
    printf '%s' "${s:0:${2:-120}}"
}

# Bound any command to ~2s: timeout(1) when present (with a kill escalation),
# else a portable background-kill emulation (stock macOS has no timeout)
bounded2() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 2 "$@" 2>/dev/null
    else
        "$@" 2>/dev/null &
        local gpid=$!
        ( sleep 2; kill "$gpid" 2>/dev/null ) >/dev/null 2>&1 &
        local kpid=$!
        wait "$gpid" 2>/dev/null
        kill "$kpid" 2>/dev/null
        wait "$kpid" 2>/dev/null
    fi
}

clamp_pct() {
    local val=$1 int
    case "$val" in
        ''|-|null|*[!0-9.]*) printf "0"; return ;;
    esac
    int=$(printf "%.0f" "$val" 2>/dev/null) || int=0
    case "$int" in ''|*[!0-9]*) int=0 ;; esac
    [ "${#int}" -gt 3 ] && int=100
    [ "$int" -gt 100 ] && int=100
    printf "%d" "$int"
}

# Escalation color for a 0-100 value: ok below warn, then warn/high/crit
state_rgb() {
    local p=$1
    if [ "$p" -ge "$CESL_CRIT" ]; then printf '%s' "$CESL_COLOR_CRIT"
    elif [ "$p" -ge "$CESL_HIGH" ]; then printf '%s' "$CESL_COLOR_HIGH"
    elif [ "$p" -ge "$CESL_WARN" ]; then printf '%s' "$CESL_COLOR_WARN"
    else printf '%s' "$CESL_COLOR_OK"
    fi
}

format_tokens() {
    local num=$1
    case "$num" in ''|*[!0-9]*) num=0 ;; esac
    if [ "$num" -ge 1000000 ]; then
        awk -v n="$num" 'BEGIN {printf "%.1fm", n / 1000000}'
    elif [ "$num" -ge 1000 ]; then
        awk -v n="$num" 'BEGIN {printf "%dk", n / 1000}'
    else
        printf "%d" "$num"
    fi
}

build_bar() { # pct width rgb -> textual escape string
    local pct=$1 width=$2 rgb=$3
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local filled_str="" empty_str="" i
    for ((i=0; i<filled; i++)); do filled_str+="$g_fill"; done
    for ((i=0; i<empty; i++)); do empty_str+="$g_empty"; done
    printf '%s' "\033[38;2;${rgb}m${filled_str}${dim}${empty_str}${reset}"
}

iso_to_epoch() {
    local iso_str="$1" epoch
    epoch=$(date -d "${iso_str}" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then printf '%s' "$epoch"; return 0; fi
    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"
    epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then
        # BSD fallback parsed as UTC; re-apply an explicit UTC offset if present
        local suf off
        suf=$(printf '%s' "$iso_str" | tail -c 6)
        case "$suf" in
            +[0-9][0-9]:[0-9][0-9])
                off=$(( 10#${suf:1:2} * 3600 + 10#${suf:4:2} * 60 ))
                epoch=$(( epoch - off ))
                ;;
            -[0-9][0-9]:[0-9][0-9])
                off=$(( 10#${suf:1:2} * 3600 + 10#${suf:4:2} * 60 ))
                epoch=$(( epoch + off ))
                ;;
        esac
        printf '%s' "$epoch"
        return 0
    fi
    return 1
}

fmt_epoch() { # style(time|day) epoch
    local style=$1 epoch=$2 out=""
    case "$style" in
        time)
            out=$(date -d "@$epoch" +"%l:%M%P" 2>/dev/null | sed 's/^ //; s/\.//g')
            [ -z "$out" ] && out=$(date -j -r "$epoch" +"%l:%M%p" 2>/dev/null | sed 's/^ //; s/\.//g' | tr 'A-Z' 'a-z')
            ;;
        day)
            out=$(date -d "@$epoch" +"%b %e" 2>/dev/null | sed 's/  / /g' | tr 'A-Z' 'a-z')
            [ -z "$out" ] && out=$(date -j -r "$epoch" +"%b %e" 2>/dev/null | sed 's/  / /g' | tr 'A-Z' 'a-z')
            ;;
    esac
    printf '%s' "$out"
}

fmt_reset_any() { # style value(epoch-seconds or ISO-8601)
    local style=$1 val=$2 epoch=""
    [ "${#val}" -gt 64 ] && return
    case "$val" in
        ''|-|null) return ;;
        *[!0-9]*) epoch=$(iso_to_epoch "$val") || return ;;
        *) [ "${#val}" -le 12 ] && epoch=$(( 10#$val )) || return ;;
    esac
    [ -n "$epoch" ] && fmt_epoch "$style" "$epoch"
}

# ── Extract stdin fields (single jq; sentinel keeps TSV aligned) ────
read_json=$(printf '%s' "$input" | jq -r '[
    ((.model.display_name)? // "Claude"),
    ((.model.id)? // ""),
    ((.cwd)? // "-"),
    ((.version)? // "2.1.34"),
    ((.output_style.name)? // "default"),
    (((.cost.total_cost_usd)? // "-") | tostring),
    (((.cost.total_duration_ms)? // "-") | tostring),
    (((.cost.total_lines_added)? // "-") | tostring),
    (((.cost.total_lines_removed)? // "-") | tostring),
    (((.context_window.context_window_size)? // 200000) | tostring),
    (((.context_window.current_usage.input_tokens)? // 0) | tostring),
    (((.context_window.current_usage.cache_creation_input_tokens)? // 0) | tostring),
    (((.context_window.current_usage.cache_read_input_tokens)? // 0) | tostring),
    (((.exceeds_200k_tokens)? // false) | tostring),
    (((.effort.level)? // "") | tostring),
    (((.fast_mode)? // false) | tostring),
    (((.thinking.enabled)? // false) | tostring),
    (((.vim.mode)? // "") | tostring),
    (((.agent | if type=="object" then (.name // "") elif type=="string" then . else "" end))? // ""),
    (((.rate_limits.five_hour.used_percentage)? // (.rate_limits.five_hour.utilization)? // "") | tostring),
    (((.rate_limits.five_hour.resets_at)? // "") | tostring),
    (((.rate_limits.seven_day.used_percentage)? // (.rate_limits.seven_day.utilization)? // "") | tostring),
    (((.rate_limits.seven_day.resets_at)? // "") | tostring)
] | map(if . == "" then "-" else . end) | @tsv' 2>/dev/null)

# Invalid/unparseable stdin must degrade to sentinels, never to empty fields
# (empty fields would shift the read and fabricate 0% rate rows)
if [ -z "$read_json" ]; then
    read_json=$(printf 'Claude\t-\t-\t2.1.34\tdefault\t-\t-\t-\t-\t200000\t0\t0\t0\tfalse\t-\tfalse\tfalse\t-\t-\t-\t-\t-\t-')
fi

IFS=$'\t' read -r model_name model_id cwd cc_version output_style \
    cost_usd duration_ms lines_added lines_removed \
    size input_tokens cache_create cache_read \
    exceeds_200k effort_level fast_mode thinking_on vim_mode agent_name \
    sl_five_pct sl_five_reset sl_seven_pct sl_seven_reset <<< "$read_json"

[ -z "$cwd" ] || [ "$cwd" = "null" ] || [ "$cwd" = "-" ] && cwd=$(pwd)
# Digits-only + length caps + base-10 forcing: leading zeros must not trip
# octal parsing, oversized values must not overflow into negatives
case "$size" in ''|0|*[!0-9]*) size=200000 ;; esac
[ "${#size}" -gt 12 ] && size=200000
case "$input_tokens" in ''|*[!0-9]*) input_tokens=0 ;; esac
[ "${#input_tokens}" -gt 12 ] && input_tokens=0
case "$cache_create" in ''|*[!0-9]*) cache_create=0 ;; esac
[ "${#cache_create}" -gt 12 ] && cache_create=0
case "$cache_read" in ''|*[!0-9]*) cache_read=0 ;; esac
[ "${#cache_read}" -gt 12 ] && cache_read=0
case "$cc_version" in ''|*[!0-9.]*) cc_version="2.1.34" ;; esac

# Untrusted display strings (sanitized + length-capped)
model_name=$(sanitize "$model_name" 40)
model_id=$(sanitize "$model_id" 64)
output_style=$(sanitize "$output_style" 24)
effort_level=$(sanitize "$effort_level" 10)
vim_mode=$(sanitize "$vim_mode" 12)
agent_name=$(sanitize "$agent_name" 40)

current=$(( 10#$input_tokens + 10#$cache_create + 10#$cache_read ))
size=$(( 10#$size ))
[ "$size" -eq 0 ] && size=200000
pct_used=$(( current * 100 / size ))
used_fmt=$(format_tokens "$current")
total_fmt=$(format_tokens "$size")

# ── Model: short name + family hue ──────────────────────────────────
short_model="${model_name/Claude /}"
model_lc=$(printf '%s %s' "$model_name" "$model_id" | tr 'A-Z' 'a-z')
case "$model_lc" in
    *opus*)          model_rgb="$CESL_COLOR_OPUS" ;;
    *sonnet*)        model_rgb="$CESL_COLOR_SONNET" ;;
    *haiku*)         model_rgb="$CESL_COLOR_HAIKU" ;;
    *fable*|*mythos*) model_rgb="$CESL_COLOR_FABLE" ;;
    *)               model_rgb="$CESL_COLOR_MODEL" ;;
esac

# ── Directory: last 2 components ────────────────────────────────────
dir_display() {
    local dir="$1"
    dir="${dir/#$HOME/\~}"
    local IFS='/'
    read -ra parts <<< "$dir"
    local count=${#parts[@]}
    if [ "$count" -le 2 ]; then
        printf '%s' "$dir"
    else
        printf '%s' "${g_ellipsis}/${parts[$((count-2))]}/${parts[$((count-1))]}"
    fi
}
dirname_short=$(sanitize "$(dir_display "$cwd")" 80)

# ── Git: branch, counts, ahead/behind, worktree ─────────────────────
git_branch=""
git_staged=0
git_unstaged=0
git_untracked=0
git_remote_status=""
is_worktree=false

if [ "$CESL_SHOW_GIT" = "1" ] && git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    git_branch=$(sanitize "$git_branch" 64)

    porcelain=$(bounded2 git -C "$cwd" --no-optional-locks status --porcelain)
    if [ -n "$porcelain" ]; then
        while IFS= read -r _line; do
            _x="${_line:0:1}"
            _y="${_line:1:1}"
            if [ "$_x" = "?" ]; then
                git_untracked=$(( git_untracked + 1 ))
            else
                [ "$_x" != " " ] && git_staged=$(( git_staged + 1 ))
                [ "$_y" != " " ] && git_unstaged=$(( git_unstaged + 1 ))
            fi
        done <<< "$porcelain"
    fi

    read -r behind ahead < <(bounded2 git -C "$cwd" rev-list --left-right --count "@{upstream}...HEAD" || echo "0 0")
    [ "$ahead" -gt 0 ] 2>/dev/null && git_remote_status+="${g_ahead}${ahead}"
    [ "$behind" -gt 0 ] 2>/dev/null && git_remote_status+="${g_behind}${behind}"

    local_git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    common_dir=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
    if [ -n "$local_git_dir" ] && [ -n "$common_dir" ] && [ "$local_git_dir" != "$common_dir" ]; then
        is_worktree=true
    fi
fi

# ── Session duration (cost.total_duration_ms) ───────────────────────
session_duration=""
case "$duration_ms" in
    ''|-|null|*[!0-9.]*) ;;
    *)
        ms_int=${duration_ms%%.*}
        case "$ms_int" in ''|*[!0-9]*) ms_int=0 ;; esac
        [ "${#ms_int}" -gt 15 ] && ms_int=0
        elapsed=$(( 10#$ms_int / 1000 ))
        if [ "$elapsed" -ge 3600 ]; then
            session_duration="$(( elapsed / 3600 ))h$(( (elapsed % 3600) / 60 ))m"
        elif [ "$elapsed" -ge 60 ]; then
            session_duration="$(( elapsed / 60 ))m"
        else
            session_duration="${elapsed}s"
        fi
        ;;
esac

# ── Session cost (converted, thresholded) ───────────────────────────
cost_fmt=""
cost_rgb=""
[ "${#cost_usd}" -gt 20 ] && cost_usd="-"
case "$cost_usd" in
    ''|-|null|*[!0-9.]*) ;;
    *)
        cost_fmt=$(awk -v c="$cost_usd" -v r="$CESL_CURRENCY_RATE" 'BEGIN {printf "%.2f", c * r}' 2>/dev/null)
        if [ -n "$cost_fmt" ]; then
            _lvl=$(awk -v c="$cost_fmt" -v w="$CESL_COST_WARN" -v x="$CESL_COST_CRIT" \
                'BEGIN { if (c >= x) print "crit"; else if (c >= w) print "warn"; else print "ok" }' 2>/dev/null)
            case "$_lvl" in
                crit) cost_rgb="$CESL_COLOR_CRIT" ;;
                warn) cost_rgb="$CESL_COLOR_WARN" ;;
            esac
        fi
        ;;
esac

# ── LINE 1 ──────────────────────────────────────────────────────────
line1=""
seg() { [ -n "$line1" ] && line1+="$sep"; line1+="$1"; }

# Model
if [ "$CESL_SHOW_MODEL" = "1" ]; then
    seg "\033[38;2;${model_rgb}m${short_model}${reset}"
fi

# Context: dim when healthy, escalation color + ⚠ when hot
if [ "$CESL_SHOW_CONTEXT" = "1" ]; then
    if [ "$pct_used" -ge "$CESL_WARN" ]; then
        ctx_rgb=$(state_rgb "$pct_used")
        ctx="\033[38;2;${ctx_rgb}m${pct_used}%${reset} ${dim}(${used_fmt}/${total_fmt})${reset}"
        [ "$pct_used" -ge "$CESL_HIGH" ] && ctx="${alert}${g_warn}${reset} ${ctx}"
    else
        ctx="${c_txt}${pct_used}%${reset} ${dim}(${used_fmt}/${total_fmt})${reset}"
    fi
    [ "$exceeds_200k" = "true" ] && ctx+=" ${alert}${g_warn}200k+${reset}"
    seg "$ctx"
fi

# Directory + git
if [ "$CESL_SHOW_DIR" = "1" ]; then
    dseg="${c_dir}${dirname_short}${reset}"
    if [ -n "$git_branch" ]; then
        dseg+=" ${dim}(${g_branch}${git_branch}${reset}"
        [ "$git_staged" -gt 0 ] && dseg+=" ${c_warn}S:${git_staged}${reset}"
        [ "$git_unstaged" -gt 0 ] && dseg+=" ${c_warn}U:${git_unstaged}${reset}"
        [ "$git_untracked" -gt 0 ] && dseg+=" ${c_warn}A:${git_untracked}${reset}"
        [ -n "$git_remote_status" ] && dseg+=" ${dim}${git_remote_status}${reset}"
        dseg+="${dim})${reset}"
    fi
    $is_worktree && dseg+=" ${dim}${g_wt}${reset}"
    seg "$dseg"
fi

# Metrics group: cost · duration · lines · effort · badges
metrics=""
madd() { [ -n "$metrics" ] && metrics+="$dot"; metrics+="$1"; }

if [ "$CESL_SHOW_COST" = "1" ] && [ -n "$cost_fmt" ] && [ "$cost_fmt" != "0.00" ]; then
    if [ -n "$cost_rgb" ]; then
        madd "\033[38;2;${cost_rgb}m${CESL_CURRENCY_SYMBOL}${cost_fmt}${reset}"
    else
        madd "${dim}${CESL_CURRENCY_SYMBOL}${reset}${c_txt}${cost_fmt}${reset}"
    fi
fi
[ "$CESL_SHOW_DURATION" = "1" ] && [ -n "$session_duration" ] && madd "${c_txt}${session_duration}${reset}"

if [ "$CESL_SHOW_LINES" = "1" ]; then
    la="" ; lr=""
    case "$lines_added"   in ''|-|null|*[!0-9]*) ;; 0) ;; *) [ "${#lines_added}" -le 9 ] && la=$lines_added ;; esac
    case "$lines_removed" in ''|-|null|*[!0-9]*) ;; 0) ;; *) [ "${#lines_removed}" -le 9 ] && lr=$lines_removed ;; esac
    if [ -n "$la" ] || [ -n "$lr" ]; then
        madd "${dim}+${la:-0}/-${lr:-0}${reset}"
    fi
fi

if [ "$CESL_SHOW_EFFORT" = "1" ] && [ "$effort_level" != "-" ] && [ -n "$effort_level" ]; then
    case "$effort_level" in
        high|xhigh|max) eff_g="$g_eff_high" ;;
        medium)         eff_g="$g_eff_med" ;;
        *)              eff_g="$g_eff_low" ;;
    esac
    madd "${dim}${eff_g} ${effort_level}${reset}"
fi

if [ "$CESL_SHOW_BADGES" = "1" ]; then
    [ "$fast_mode" = "true" ] && madd "${dim}fast${reset}"
    [ "$thinking_on" = "true" ] && madd "${dim}think${reset}"
    [ "$vim_mode" != "-" ] && [ -n "$vim_mode" ] && madd "${dim}vim${reset}"
    [ "$output_style" != "default" ] && [ "$output_style" != "-" ] && madd "${dim}${output_style}${reset}"
    [ "$agent_name" != "-" ] && [ -n "$agent_name" ] && madd "${c_agent}[${agent_name}]${reset}"
fi

[ -n "$metrics" ] && seg "$metrics"

# ── OAuth token resolution (enrichment only) ────────────────────────
get_oauth_token() {
    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        local token
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            echo "$token"
            return 0
        fi
    fi
    if command -v secret-tool >/dev/null 2>&1; then
        local blob token
        blob=$(bounded2 secret-tool lookup service "Claude Code-credentials")
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi
    if command -v security >/dev/null 2>&1; then
        local blob token
        blob=$(bounded2 security find-generic-password -s "Claude Code-credentials" -w)
        if [ -n "$blob" ]; then
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi
    echo ""
}

# ── Usage API fetch (cached; extra usage + scoped limits only) ──────
cache_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-statusline-$(id -u)"
cache_file="$cache_dir/usage-cache.json"
usage_data=""

if [ "$CESL_SHOW_RATE_BLOCK" = "1" ]; then
    mkdir -m 700 -p "$cache_dir" 2>/dev/null
    if [ ! -d "$cache_dir" ] || [ -L "$cache_dir" ] || [ ! -O "$cache_dir" ]; then
        cache_file=""
    else
        chmod 700 "$cache_dir" 2>/dev/null
    fi

    needs_refresh=true
    if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
        cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
        now=$(date +%s)
        cache_age=$(( now - cache_mtime ))
        cache_size=$(wc -c < "$cache_file" 2>/dev/null)
        case "$cache_size" in ''|*[!0-9]*) cache_size=9999999 ;; esac
        if [ "$cache_age" -lt "$CESL_CACHE_TTL" ] && [ "$cache_size" -le 1048576 ] \
           && jq -e '.five_hour' "$cache_file" >/dev/null 2>&1; then
            needs_refresh=false
            usage_data=$(cat "$cache_file" 2>/dev/null)
        fi
    fi

    if $needs_refresh; then
        # Negative cache: after a failed fetch, back off for one TTL instead of
        # paying token resolution + curl timeout on every render
        fail_marker="$cache_dir/usage-fail"
        skip_fetch=false
        if [ -n "$cache_file" ] && [ -f "$fail_marker" ]; then
            fm_mtime=$(stat -c %Y "$fail_marker" 2>/dev/null || stat -f %m "$fail_marker" 2>/dev/null)
            now=$(date +%s)
            [ $(( now - fm_mtime )) -lt "$CESL_CACHE_TTL" ] 2>/dev/null && skip_fetch=true
        fi

        # Single-flight lock: concurrent sessions must not stampede the API
        # when the shared cache expires (stale locks broken after 30s)
        lock_dir=""
        if ! $skip_fetch && [ -n "$cache_file" ]; then
            lock_dir="$cache_dir/fetch.lock"
            if ! mkdir "$lock_dir" 2>/dev/null; then
                l_mtime=$(stat -c %Y "$lock_dir" 2>/dev/null || stat -f %m "$lock_dir" 2>/dev/null)
                now=$(date +%s)
                if [ $(( now - ${l_mtime:-0} )) -gt 30 ] 2>/dev/null; then
                    rm -rf "$lock_dir" 2>/dev/null
                    mkdir "$lock_dir" 2>/dev/null || { skip_fetch=true; lock_dir=""; }
                else
                    skip_fetch=true
                    lock_dir=""
                fi
            fi
        fi

        if ! $skip_fetch; then
            token=$(get_oauth_token)
            # OAuth tokens are URL-safe strings; anything else could inject
            # directives into the curl config below — refuse it
            case "$token" in *[!A-Za-z0-9._~+/=-]*) token="" ;; esac
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                # Token goes to curl via stdin config, never on argv (procfs-visible)
                response=$(printf 'header = "Authorization: Bearer %s"\n' "$token" | curl -s --max-time 5 \
                    --max-filesize 1048576 \
                    -H "Accept: application/json" \
                    -H "Content-Type: application/json" \
                    -H "anthropic-beta: oauth-2025-04-20" \
                    -H "User-Agent: claude-code/${cc_version}" \
                    --config - \
                    "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
                if [ -n "$response" ] && printf '%s' "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
                    usage_data="$response"
                    if [ -n "$cache_file" ]; then
                        printf '%s\n' "$response" > "$cache_file.$$" && mv -f "$cache_file.$$" "$cache_file"
                        rm -f "$fail_marker" 2>/dev/null
                    fi
                elif [ -n "$cache_file" ]; then
                    touch "$fail_marker" 2>/dev/null
                fi
            elif [ -n "$cache_file" ]; then
                touch "$fail_marker" 2>/dev/null
            fi
            [ -n "$lock_dir" ] && rmdir "$lock_dir" 2>/dev/null
        fi
        if [ -z "$usage_data" ] && [ -n "$cache_file" ] && [ -f "$cache_file" ] \
           && [ "$(wc -c < "$cache_file" 2>/dev/null)" -le 1048576 ] 2>/dev/null \
           && jq -e '.five_hour' "$cache_file" >/dev/null 2>&1; then
            usage_data=$(cat "$cache_file" 2>/dev/null)
        fi
    fi
fi

# ── Rate-limit block ────────────────────────────────────────────────
rate_lines=""

rate_row() { # label pct reset_style reset_val [value_text]
    local label=$1 pct=$2 style=$3 rval=$4 vtext=$5
    local rgb bar pfmt line rst
    rgb=$(state_rgb "$pct")
    bar=$(build_bar "$pct" "$CESL_BAR_WIDTH" "$rgb")
    line=$(printf '%-7.7s' "$label")
    line="${c_txt}${line}${reset} ${bar}"
    if [ -n "$vtext" ]; then
        line+=" ${vtext}"
    else
        pfmt=$(printf '%3d' "$pct")
        line+=" \033[38;2;${rgb}m${pfmt}%${reset}"
    fi
    rst=$(fmt_reset_any "$style" "$rval")
    [ -n "$rst" ] && line+=" ${dim}${g_reset}${reset} ${c_txt}${rst}${reset}"
    [ -n "$rate_lines" ] && rate_lines+="\n"
    rate_lines+="$line"
}

if [ "$CESL_SHOW_RATE_BLOCK" = "1" ]; then
    # 5-hour / 7-day: stdin is authoritative
    if [ "$sl_five_pct" != "-" ]; then
        rate_row "5-hour" "$(clamp_pct "$sl_five_pct")" time "$sl_five_reset"
    fi
    if [ "$sl_seven_pct" != "-" ]; then
        rate_row "7-day" "$(clamp_pct "$sl_seven_pct")" day "$sl_seven_reset"
    fi

    if [ -n "$usage_data" ]; then
        # Per-model scoped weekly limits (undocumented limits[]; defensive)
        scoped=$(printf '%s' "$usage_data" | jq -r '
            ((.limits)? // []) |
            (if type == "array" then . else [] end) |
            map(select(((.kind)? // "") == "weekly_scoped" and ((.is_active)? != false))) |
            .[] | [
                (((.scope.model.display_name)? // (.scope.model.id)? // (.group)? // "model") | tostring),
                (((.percent)? // 0) | tostring),
                (((.resets_at)? // "-") | tostring)
            ] | map(if . == "" then "-" else . end) | @tsv' 2>/dev/null | head -n 8)
        if [ -n "$scoped" ]; then
            while IFS=$'\t' read -r sc_label sc_pct sc_reset; do
                [ -z "$sc_label" ] || [ "$sc_label" = "-" ] && continue
                sc_label=$(sanitize "$sc_label" | tr 'A-Z' 'a-z')
                rate_row "$sc_label" "$(clamp_pct "$sc_pct")" day "$sc_reset"
            done <<< "$scoped"
        fi

        # Extra usage (credits) — only when enabled
        read_extra=$(printf '%s' "$usage_data" | jq -r '[
            (((.extra_usage.is_enabled)? // false) | tostring),
            (((.extra_usage.utilization)? // 0) | tostring),
            (((.extra_usage.used_credits)? // 0) | tostring),
            (((.extra_usage.monthly_limit)? // 0) | tostring)
        ] | map(if . == "" then "-" else . end) | @tsv' 2>/dev/null)
        IFS=$'\t' read -r extra_enabled extra_pct_raw extra_used_raw extra_limit_raw <<< "$read_extra"

        if [ "$extra_enabled" = "true" ]; then
            extra_pct=$(clamp_pct "$extra_pct_raw")
            extra_used=$(awk -v v="$extra_used_raw" 'BEGIN {printf "%.2f", v / 100}')
            extra_limit=$(awk -v v="$extra_limit_raw" 'BEGIN {printf "%.2f", v / 100}')
            extra_rgb=$(state_rgb "$extra_pct")
            extra_val="\033[38;2;${extra_rgb}m${CESL_CURRENCY_SYMBOL}${extra_used}${reset}${dim}/${reset}${c_txt}${CESL_CURRENCY_SYMBOL}${extra_limit}${reset}"
            extra_reset=$(date -d "$(date +%Y-%m-01) +1 month" +"%b %e" 2>/dev/null | sed 's/  / /g' | tr 'A-Z' 'a-z')
            [ -z "$extra_reset" ] && extra_reset=$(date -v1d -v+1m +"%b %e" 2>/dev/null | sed 's/  / /g' | tr 'A-Z' 'a-z')
            rate_row "extra" "$extra_pct" none "" "$extra_val"
            [ -n "$extra_reset" ] && rate_lines+=" ${dim}${g_reset}${reset} ${c_txt}${extra_reset}${reset}"
        fi
    fi
fi

# ── Explain mode ────────────────────────────────────────────────────
if [ "$mode" = "explain" ]; then
    echo "Claude Epic Status Line — explain"
    echo
    echo "== raw stdin =="
    if [ -n "$input" ]; then
        if ! printf '%s' "$input" | jq . 2>/dev/null; then
            # keep newlines/tabs, strip every other control char (terminal safety)
            printf '%s' "$input" | tr -d '\000-\010\013-\037\177'
            printf '\n(not valid JSON)\n'
        fi
    else
        echo "(empty — pipe the statusline JSON in: cat sample.json | ./statusline.sh explain)"
    fi
    echo
    echo "== parsed =="
    echo "model:        $model_name (id: $model_id, family rgb: $model_rgb)"
    echo "version:      $cc_version"
    echo "cwd:          $(sanitize "$cwd" 200)"
    echo "context:      $current/$size tokens ($pct_used%), exceeds_200k=$exceeds_200k"
    echo "cost:         raw=$cost_usd display=${cost_fmt:-n/a} ${CESL_CURRENCY_SYMBOL} (rate $CESL_CURRENCY_RATE)"
    echo "duration:     raw_ms=$duration_ms display=${session_duration:-n/a}"
    echo "lines:        +$lines_added/-$lines_removed"
    echo "effort:       $effort_level | fast: $fast_mode | thinking: $thinking_on | vim: $vim_mode"
    echo "output_style: $output_style | agent: $agent_name"
    echo "git:          branch=${git_branch:-n/a} S=$git_staged U=$git_unstaged A=$git_untracked remote=$git_remote_status worktree=$is_worktree"
    echo "stdin limits: 5h=$(sanitize "$sl_five_pct" 20)% reset=$(sanitize "$sl_five_reset" 40) | 7d=$(sanitize "$sl_seven_pct" 20)% reset=$(sanitize "$sl_seven_reset" 40)"
    echo
    echo "== usage api =="
    if [ -n "$usage_data" ]; then
        echo "cache: ${cache_file:-disabled} (ttl ${CESL_CACHE_TTL}s)"
        printf '%s' "$usage_data" | jq '{five_hour, seven_day, extra_usage, limits}' 2>/dev/null
    else
        echo "no data (no token, API unreachable, or rate block disabled)"
    fi
    echo
    echo "== config =="
    set | grep '^CESL_' | sort
    exit 0
fi

# ── Output ──────────────────────────────────────────────────────────
printf "%b" "$line1"
[ -n "$rate_lines" ] && printf "\n\n%b" "$rate_lines"

exit 0

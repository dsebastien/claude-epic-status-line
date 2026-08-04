#!/usr/bin/env bash
# Claude Code statusLine — colors, rate limits, session duration, cost, worktree
set -f
export LC_ALL=C

input=$(cat)

if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ── Colors ──────────────────────────────────────────────
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;175;80m'
cyan='\033[38;2;86;182;194m'
red='\033[38;2;255;85;85m'
yellow='\033[38;2;230;200;0m'
white='\033[38;2;220;220;220m'
magenta='\033[38;2;180;140;255m'
dim='\033[2m'
reset='\033[0m'
blink='\033[5m'

sep=" ${dim}│${reset} "

# ── Helpers ─────────────────────────────────────────────
format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        awk "BEGIN {printf \"%.1fm\", $num / 1000000}"
    elif [ "$num" -ge 1000 ]; then
        awk "BEGIN {printf \"%.0fk\", $num / 1000}"
    else
        printf "%d" "$num"
    fi
}

clamp_pct() {
    local val=$1 int
    case "$val" in
        ''|null|*[!0-9.]*) printf "0"; return ;;
    esac
    int=$(printf "%.0f" "$val" 2>/dev/null) || int=0
    case "$int" in ''|*[!0-9]*) int=0 ;; esac
    [ "${#int}" -gt 3 ] && int=100
    [ "$int" -gt 100 ] && int=100
    printf "%d" "$int"
}

color_for_pct() {
    local pct=$1
    if [ "$pct" -ge 90 ]; then printf "$red"
    elif [ "$pct" -ge 70 ]; then printf "$yellow"
    elif [ "$pct" -ge 50 ]; then printf "$orange"
    else printf "$green"
    fi
}

build_bar() {
    local pct=$1
    local width=$2
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100

    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local bar_color
    bar_color=$(color_for_pct "$pct")

    local filled_str="" empty_str=""
    for ((i=0; i<filled; i++)); do filled_str+="●"; done
    for ((i=0; i<empty; i++)); do empty_str+="○"; done

    printf "${bar_color}${filled_str}${dim}${empty_str}${reset}"
}

shorten_model() {
    local name="$1"
    name="${name/Claude /}"
    printf "%s" "$name"
}

iso_to_epoch() {
    local iso_str="$1"
    local epoch
    epoch=$(date -d "${iso_str}" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then
        echo "$epoch"
        return 0
    fi
    local stripped="${iso_str%%.*}"
    stripped="${stripped%%Z}"
    stripped="${stripped%%+*}"
    stripped="${stripped%%-[0-9][0-9]:[0-9][0-9]}"
    epoch=$(date -j -u -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null)
    if [ -n "$epoch" ]; then
        echo "$epoch"
        return 0
    fi
    return 1
}

format_reset_time() {
    local iso_str="$1"
    local style="$2"
    [ -z "$iso_str" ] || [ "$iso_str" = "null" ] || [ "$iso_str" = "-" ] && return

    local epoch
    epoch=$(iso_to_epoch "$iso_str")
    [ -z "$epoch" ] && return

    local result=""
    case "$style" in
        time)
            result=$(date -d "@$epoch" +"%l:%M%P" 2>/dev/null | sed 's/^ //; s/\.//g')
            [ -z "$result" ] && result=$(date -j -r "$epoch" +"%l:%M%p" 2>/dev/null | sed 's/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
            ;;
        datetime)
            result=$(date -d "@$epoch" +"%b %-d, %l:%M%P" 2>/dev/null | sed 's/  / /g; s/^ //; s/\.//g')
            [ -z "$result" ] && result=$(date -j -r "$epoch" +"%b %e, %l:%M%p" 2>/dev/null | sed 's/  / /g; s/^ //; s/\.//g' | tr '[:upper:]' '[:lower:]')
            ;;
    esac
    printf "%s" "$result"
}

# ── Extract all JSON fields in one jq call ──────────────
read_json=$(echo "$input" | jq -r '[
    (.model.display_name // "Claude"),
    (.cwd // ""),
    (.context_window.context_window_size // 200000 | tostring),
    (.context_window.current_usage.input_tokens // 0 | tostring),
    (.context_window.current_usage.cache_creation_input_tokens // 0 | tostring),
    (.context_window.current_usage.cache_read_input_tokens // 0 | tostring),
    (.cost.total_cost_usd // "" | tostring),
    (.cost.total_duration_ms // "" | tostring),
    (.version // "2.1.34")
] | map(if . == "" then "-" else . end) | @tsv')

IFS=$'\t' read -r model_name cwd size input_tokens cache_create cache_read cost_usd duration_ms cc_version <<< "$read_json"

[ -z "$cwd" ] || [ "$cwd" = "null" ] || [ "$cwd" = "-" ] && cwd=$(pwd)
case "$size" in ''|0|*[!0-9]*) size=200000 ;; esac
case "$input_tokens" in ''|*[!0-9]*) input_tokens=0 ;; esac
case "$cache_create" in ''|*[!0-9]*) cache_create=0 ;; esac
case "$cache_read" in ''|*[!0-9]*) cache_read=0 ;; esac
case "$cc_version" in ''|*[!0-9.]*) cc_version="2.1.34" ;; esac

current=$(( input_tokens + cache_create + cache_read ))

if [ "$size" -gt 0 ]; then
    pct_used=$(( current * 100 / size ))
else
    pct_used=0
fi

used_fmt=$(format_tokens "$current")
total_fmt=$(format_tokens "$size")
short_model=$(shorten_model "$model_name")

# ── Directory: last 2 components ────────────────────────
dir_display() {
    local dir="$1"
    dir="${dir/#$HOME/\~}"
    local IFS='/'
    read -ra parts <<< "$dir"
    local count=${#parts[@]}
    if [ "$count" -le 2 ]; then
        echo "$dir"
    else
        echo "…/${parts[$((count-2))]}/${parts[$((count-1))]}"
    fi
}

dirname_short=$(dir_display "$cwd")

# ── Git: branch, dirty, ahead/behind, worktree ─────────
git_branch=""
git_staged=0
git_unstaged=0
git_untracked=0
git_remote_status=""
is_worktree=false

if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)

    if command -v timeout >/dev/null 2>&1; then
        porcelain=$(timeout 2 git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
    else
        porcelain=$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)
    fi
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

    read -r behind ahead < <(git -C "$cwd" rev-list --left-right --count "@{upstream}...HEAD" 2>/dev/null || echo "0 0")
    [ "$ahead" -gt 0 ] 2>/dev/null && git_remote_status+="⇡${ahead}"
    [ "$behind" -gt 0 ] 2>/dev/null && git_remote_status+="⇣${behind}"

    # Detect worktree (git-dir differs from common-dir)
    local_git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    common_dir=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
    if [ -n "$local_git_dir" ] && [ -n "$common_dir" ] && [ "$local_git_dir" != "$common_dir" ]; then
        is_worktree=true
    fi
fi

# ── Session duration ────────────────────────────────────
session_duration=""
case "$duration_ms" in
    ''|null|*[!0-9.]*) ;;
    *)
        ms_int=${duration_ms%%.*}
        case "$ms_int" in ''|*[!0-9]*) ms_int=0 ;; esac
        elapsed=$(( ms_int / 1000 ))
        if [ "$elapsed" -ge 3600 ]; then
            session_duration="$(( elapsed / 3600 ))h$(( (elapsed % 3600) / 60 ))m"
        elif [ "$elapsed" -ge 60 ]; then
            session_duration="$(( elapsed / 60 ))m"
        else
            session_duration="${elapsed}s"
        fi
        ;;
esac

# ── Effort level (from settings, single jq call) ───────
effort="default"
settings_path="$HOME/.claude/settings.json"
if [ -f "$settings_path" ]; then
    effort=$(jq -r '.effortLevel // "default"' "$settings_path" 2>/dev/null)
fi

# ── LINE 1: Model │ Context │ Dir (branch) │ Cost │ Session │ Effort ──
pct_color=$(color_for_pct "$pct_used")

# Auto-compact warning: highlight context when >= 80%
ctx_segment="${pct_color}${pct_used}%${reset} ${dim}(${used_fmt}/${total_fmt})${reset}"
if [ "$pct_used" -ge 80 ]; then
    ctx_segment="${blink}${red}⚠${reset} ${ctx_segment}"
fi

line1="${blue}${short_model}${reset}"
line1+="${sep}"
line1+="${ctx_segment}"
line1+="${sep}"
line1+="${cyan}${dirname_short}${reset}"
if [ -n "$git_branch" ]; then
    line1+=" ${green}(${git_branch}"
    [ "$git_staged" -gt 0 ] && line1+=" ${yellow}S:${git_staged}${reset}"
    [ "$git_unstaged" -gt 0 ] && line1+=" ${red}U:${git_unstaged}${reset}"
    [ "$git_untracked" -gt 0 ] && line1+=" ${cyan}A:${git_untracked}${reset}"
    [ -n "$git_remote_status" ] && line1+=" ${yellow}${git_remote_status}${reset}"
    line1+="${green})${reset}"
fi
if $is_worktree; then
    line1+=" ${magenta}⎇wt${reset}"
fi

# Session cost (cost.total_cost_usd)
cost_fmt=""
case "$cost_usd" in
    ''|null|*[!0-9.]*) ;;
    *) cost_fmt=$(printf "%.2f" "$cost_usd" 2>/dev/null) ;;
esac
if [ -n "$cost_fmt" ] && [ "$cost_fmt" != "0.00" ]; then
    line1+="${sep}"
    line1+="${dim}\$${reset}${white}${cost_fmt}${reset}"
fi

if [ -n "$session_duration" ]; then
    line1+="${sep}"
    line1+="${dim}⏱ ${reset}${white}${session_duration}${reset}"
fi

line1+="${sep}"
case "$effort" in
    high)   line1+="${magenta}● ${effort}${reset}" ;;
    medium) line1+="${dim}◑ ${effort}${reset}" ;;
    low)    line1+="${dim}◔ ${effort}${reset}" ;;
    *)      line1+="${dim}◑ ${effort}${reset}" ;;
esac

# ── OAuth token resolution ──────────────────────────────
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
        local blob
        blob=$(timeout 2 secret-tool lookup service "Claude Code-credentials" 2>/dev/null)
        if [ -n "$blob" ]; then
            local token
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi

    if command -v security >/dev/null 2>&1; then
        local blob
        blob=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
        if [ -n "$blob" ]; then
            local token
            token=$(echo "$blob" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
            if [ -n "$token" ] && [ "$token" != "null" ]; then
                echo "$token"
                return 0
            fi
        fi
    fi

    echo ""
}

# ── Fetch usage data (cached 60s) ───────────────────────
cache_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-statusline-$(id -u)"
cache_file="$cache_dir/usage-cache.json"
cache_max_age=60
mkdir -m 700 -p "$cache_dir" 2>/dev/null
if [ ! -d "$cache_dir" ] || [ -L "$cache_dir" ] || [ ! -O "$cache_dir" ]; then
    cache_file=""
fi

needs_refresh=true
usage_data=""

if [ -f "$cache_file" ]; then
    cache_mtime=$(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)
    now=$(date +%s)
    cache_age=$(( now - cache_mtime ))
    if [ "$cache_age" -lt "$cache_max_age" ] && jq -e '.five_hour' "$cache_file" >/dev/null 2>&1; then
        needs_refresh=false
        usage_data=$(cat "$cache_file" 2>/dev/null)
    fi
fi

if $needs_refresh; then
    token=$(get_oauth_token)
    if [ -n "$token" ] && [ "$token" != "null" ]; then
        response=$(curl -s --max-time 5 \
            -H "Accept: application/json" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $token" \
            -H "anthropic-beta: oauth-2025-04-20" \
            -H "User-Agent: claude-code/${cc_version}" \
            "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
        if [ -n "$response" ] && echo "$response" | jq -e '.five_hour' >/dev/null 2>&1; then
            usage_data="$response"
            if [ -n "$cache_file" ]; then
                printf '%s\n' "$response" > "$cache_file.$$" && mv -f "$cache_file.$$" "$cache_file"
            fi
        fi
    fi
    if [ -z "$usage_data" ] && [ -f "$cache_file" ] && jq -e '.five_hour' "$cache_file" >/dev/null 2>&1; then
        usage_data=$(cat "$cache_file" 2>/dev/null)
    fi
fi

# ── Rate limit lines (single jq call for all fields) ────
rate_lines=""

if [ -n "$usage_data" ] && echo "$usage_data" | jq -e . >/dev/null 2>&1; then
    bar_width=10

    read_usage=$(echo "$usage_data" | jq -r '[
        (.five_hour.utilization // 0 | tostring),
        (.five_hour.resets_at // ""),
        (.seven_day.utilization // 0 | tostring),
        (.seven_day.resets_at // ""),
        (.extra_usage.is_enabled // false | tostring),
        (.extra_usage.utilization // 0 | tostring),
        (.extra_usage.used_credits // 0 | tostring),
        (.extra_usage.monthly_limit // 0 | tostring)
    ] | map(if . == "" then "-" else . end) | @tsv')

    IFS=$'\t' read -r five_pct_raw five_reset_iso seven_pct_raw seven_reset_iso extra_enabled extra_pct_raw extra_used_raw extra_limit_raw <<< "$read_usage"

    five_hour_pct=$(clamp_pct "$five_pct_raw")
    five_hour_reset=$(format_reset_time "$five_reset_iso" "time")
    five_hour_bar=$(build_bar "$five_hour_pct" "$bar_width")
    five_hour_pct_color=$(color_for_pct "$five_hour_pct")
    five_hour_pct_fmt=$(printf "%3d" "$five_hour_pct")

    rate_lines+="${white}current${reset} ${five_hour_bar} ${five_hour_pct_color}${five_hour_pct_fmt}%${reset}"
    [ -n "$five_hour_reset" ] && rate_lines+=" ${dim}⟳${reset} ${white}${five_hour_reset}${reset}"

    seven_day_pct=$(clamp_pct "$seven_pct_raw")
    seven_day_reset=$(format_reset_time "$seven_reset_iso" "datetime")
    seven_day_bar=$(build_bar "$seven_day_pct" "$bar_width")
    seven_day_pct_color=$(color_for_pct "$seven_day_pct")
    seven_day_pct_fmt=$(printf "%3d" "$seven_day_pct")

    rate_lines+="\n${white}weekly${reset}  ${seven_day_bar} ${seven_day_pct_color}${seven_day_pct_fmt}%${reset}"
    [ -n "$seven_day_reset" ] && rate_lines+=" ${dim}⟳${reset} ${white}${seven_day_reset}${reset}"

    if [ "$extra_enabled" = "true" ]; then
        extra_pct=$(clamp_pct "$extra_pct_raw")
        extra_used=$(awk -v v="$extra_used_raw" 'BEGIN {printf "%.2f", v / 100}')
        extra_limit=$(awk -v v="$extra_limit_raw" 'BEGIN {printf "%.2f", v / 100}')
        extra_bar=$(build_bar "$extra_pct" "$bar_width")
        extra_pct_color=$(color_for_pct "$extra_pct")

        extra_reset=$(date -d "$(date +%Y-%m-01) +1 month" +"%b %-d" 2>/dev/null | tr '[:upper:]' '[:lower:]')
        [ -z "$extra_reset" ] && extra_reset=$(date -v+1m -v1d +"%b %e" 2>/dev/null | sed 's/  / /g' | tr '[:upper:]' '[:lower:]')

        rate_lines+="\n${white}extra${reset}   ${extra_bar} ${extra_pct_color}\$${extra_used}${dim}/${reset}${white}\$${extra_limit}${reset}"
        [ -n "$extra_reset" ] && rate_lines+=" ${dim}⟳${reset} ${white}${extra_reset}${reset}"
    fi
fi

# ── Output ──────────────────────────────────────────────
printf "%b" "$line1"
[ -n "$rate_lines" ] && printf "\n\n%b" "$rate_lines"

exit 0

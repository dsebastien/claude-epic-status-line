#!/usr/bin/env bash
# Claude Epic Status Line v2 — refined status line + rate-limit dashboard
#
# Data sources:
#   - Claude Code statusline stdin JSON (authoritative: model, context, cost,
#     git cwd, effort, badges, 5-hour/7-day rate limits, prompt cache)
#     [Claude Code >= 2.1.140]
#   - OAuth usage API (optional enrichment only: extra-usage credits and
#     per-model scoped weekly limits; skipped when no token is resolvable).
#     Fetched in the background, never on the render path.
#
# Configuration (all optional):
#   defaults below  <  ~/.config/claude-epic-status-line/config.sh  <  CESL_* env vars
#
# Subcommands:
#   statusline.sh explain   (with the same stdin) dumps the received JSON and
#                           every parsed value instead of rendering
#   statusline.sh version   prints the version
#
# Colour honours NO_COLOR and TERM=dumb unless CESL_COLOR forces it.
#
# Performance rule: a render must start as few processes as possible. Claude
# Code cancels a render that is still running when the next update arrives, so
# a slow script shows stale numbers; and a process costs ~60 ms on Windows
# (Git Bash). The render path is bash builtins plus one jq and one git call.
# Helpers return through the global $_r instead of $(...), which would fork.
set -f
export LC_ALL=C
shopt -s extglob

cesl_version="2.3.0"

mode="${1:-}"
case "$mode" in
    version|--version|-v)
        printf 'Claude Epic Status Line %s\n' "$cesl_version"
        exit 0
        ;;
esac

input=""
if [ ! -t 0 ]; then
    # Builtin read (no fork), capped at 1 MiB
    IFS= read -r -d '' -n 1048576 input
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
# Any CESL_* variable that exists at this point came from the environment:
# save them, source the config file, then put them back on top.
_cesl_names="${!CESL_@}"
for _n in $_cesl_names; do
    printf -v "_ceslenv_$_n" '%s' "${!_n}"
done
_cesl_cfg="${CESL_CONFIG:-$HOME/.config/claude-epic-status-line/config.sh}"
[ -f "$_cesl_cfg" ] && . "$_cesl_cfg"
for _n in $_cesl_names; do
    _v="_ceslenv_$_n"
    printf -v "$_n" '%s' "${!_v}"
    unset "$_v"
done
unset _n _v _cesl_names

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
: "${CESL_SHOW_TURN:=1}"
: "${CESL_SHOW_HINT:=1}"
: "${CESL_SHOW_RATE_BLOCK:=1}"
# Prompt-cache state: when the cache goes cold, and what the next turn then costs
: "${CESL_SHOW_CACHE:=1}"
# Rate-block rows that need the usage API — each independently switchable, so
# hiding one does not force the whole dashboard off
: "${CESL_SHOW_SCOPED:=1}"
: "${CESL_SHOW_EXTRA:=1}"
# Projected end-of-window utilization on the 5-hour / 7-day rows
: "${CESL_SHOW_PROJECTION:=1}"
# Absolute context thresholds, in tokens. A percentage hides what a turn costs:
# 486k of a 1M window reads as a comfortable 49% while costing 48k every turn (at a 10% cache-read rate).
: "${CESL_CTX_WARN:=60000}"
: "${CESL_CTX_HIGH:=120000}"
# Share of the re-sent context that is billed each turn (cache-read rate).
# "auto" picks the rate of the current model: Opus 5.5 and Sonnet 5.5 read
# cache at 5% of the input price, Fable/Mythos 5.1 and 5.2 at 2.5%, every other model at 10%
: "${CESL_TURN_RATE:=auto}"
# Colour: auto (honour NO_COLOR / TERM=dumb) | 1 (always) | 0 (never)
: "${CESL_COLOR:=auto}"
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
[ "${#CESL_WARN}" -gt 6 ] && CESL_WARN=70
[ "${#CESL_HIGH}" -gt 6 ] && CESL_HIGH=80
[ "${#CESL_CRIT}" -gt 6 ] && CESL_CRIT=90
case "$CESL_BAR_WIDTH" in ''|0|*[!0-9]*) CESL_BAR_WIDTH=10 ;; esac
[ "${#CESL_BAR_WIDTH}" -gt 3 ] && CESL_BAR_WIDTH=10
CESL_BAR_WIDTH=$(( 10#$CESL_BAR_WIDTH ))
[ "$CESL_BAR_WIDTH" -eq 0 ] && CESL_BAR_WIDTH=10
[ "$CESL_BAR_WIDTH" -gt 200 ] && CESL_BAR_WIDTH=200
case "$CESL_CACHE_TTL" in ''|*[!0-9]*) CESL_CACHE_TTL=60 ;; esac
[ "${#CESL_CACHE_TTL}" -gt 7 ] && CESL_CACHE_TTL=60
CESL_CACHE_TTL=$(( 10#$CESL_CACHE_TTL ))
CESL_WARN=$(( 10#$CESL_WARN )); CESL_HIGH=$(( 10#$CESL_HIGH )); CESL_CRIT=$(( 10#$CESL_CRIT ))
case "$CESL_CTX_WARN" in ''|*[!0-9]*) CESL_CTX_WARN=60000 ;; esac
[ "${#CESL_CTX_WARN}" -gt 12 ] && CESL_CTX_WARN=60000
case "$CESL_CTX_HIGH" in ''|*[!0-9]*) CESL_CTX_HIGH=120000 ;; esac
[ "${#CESL_CTX_HIGH}" -gt 12 ] && CESL_CTX_HIGH=120000
CESL_CTX_WARN=$(( 10#$CESL_CTX_WARN )); CESL_CTX_HIGH=$(( 10#$CESL_CTX_HIGH ))

# A rate is a share: one number in [0, 1], kept as parts per million so the
# arithmetic stays in the shell. Anything else falls back to auto.
rate_to_ppm() { # decimal-string -> $_r (ppm); returns 1 when invalid
    local r=$1 i f re='^([0-9]+\.?[0-9]*|\.[0-9]+)$'
    [ "${#r}" -le 8 ] || return 1
    [[ $r =~ $re ]] || return 1
    i=${r%%.*}
    f=""
    case "$r" in *.*) f=${r#*.} ;; esac
    f="${f}000000"
    f=${f:0:6}
    [ -z "$i" ] && i=0
    _r=$(( 10#$i * 1000000 + 10#$f ))
    [ "$_r" -le 1000000 ]
}
_cesl_turn_raw="$CESL_TURN_RATE"
turn_ppm=""
if [ "$CESL_TURN_RATE" != "auto" ]; then
    if rate_to_ppm "$CESL_TURN_RATE"; then
        turn_ppm=$_r
    else
        CESL_TURN_RATE=auto
    fi
fi

# ── Colour gate ─────────────────────────────────────────────────────
# Everything is still built with escapes; they are stripped at output time so
# no segment can accidentally leak colour when it is switched off.
case "$CESL_COLOR" in
    0|no|off|never)  cesl_color=0 ;;
    1|yes|on|always) cesl_color=1 ;;
    *)
        cesl_color=1
        [ -n "${NO_COLOR:-}" ] && cesl_color=0
        [ "${TERM:-}" = "dumb" ] && cesl_color=0
        ;;
esac

# ── Glyphs ──────────────────────────────────────────────────────────
case "$CESL_GLYPHS" in
    ascii)
        g_sep="|"  g_fill="#" g_empty="." g_warn="!" g_reset="~"
        g_dot="-"  g_ellipsis="..." g_ahead="^" g_behind="v" g_wt="wt"
        g_eff_high="*" g_eff_med="o" g_eff_low="." g_branch="" g_proj="->"
        ;;
    nerd)
        g_sep="│"  g_fill="█" g_empty="░" g_warn="⚠︎" g_reset="⟳"
        g_dot="·"  g_ellipsis="…" g_ahead="⇡" g_behind="⇣" g_wt="⎇wt"
        g_eff_high="●" g_eff_med="◑" g_eff_low="◔" g_branch=" " g_proj="⇢"
        ;;
    *)
        g_sep="│"  g_fill="█" g_empty="░" g_warn="⚠︎" g_reset="⟳"
        g_dot="·"  g_ellipsis="…" g_ahead="⇡" g_behind="⇣" g_wt="⎇wt"
        g_eff_high="●" g_eff_med="◑" g_eff_low="◔" g_branch="" g_proj="⇢"
        ;;
esac

# ── ANSI ────────────────────────────────────────────────────────────
dim='\033[2m'
bold='\033[1m'
reset='\033[0m'
c_txt="\033[38;2;${CESL_COLOR_TEXT}m"
c_warn="\033[38;2;${CESL_COLOR_WARN}m"
c_dir="\033[38;2;${CESL_COLOR_DIR}m"
c_agent="\033[38;2;${CESL_COLOR_AGENT}m"
alert="${bold}\033[38;2;${CESL_COLOR_CRIT}m"

sep=" ${dim}${g_sep}${reset} "
dot=" ${dim}${g_dot}${reset} "

US=$'\037'   # field separator for everything jq hands back (never in clean data)

# ── Clock ───────────────────────────────────────────────────────────
# bash >= 4.2 formats time with a printf builtin; bash 3.2 (stock macOS)
# falls back to date(1).
have_tfmt=0
if [ "${BASH_VERSINFO[0]:-0}" -gt 4 ] \
   || { [ "${BASH_VERSINFO[0]:-0}" -eq 4 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 2 ]; }; then
    have_tfmt=1
fi
now=""
if [ "$have_tfmt" = "1" ]; then
    printf -v now '%(%s)T' -1 2>/dev/null
fi
case "$now" in ''|*[!0-9]*) now=$(date +%s 2>/dev/null) ;; esac
case "$now" in ''|*[!0-9]*) now=0 ;; esac
# Test hook: a fixed clock (tests/run.sh)
case "${CESL_NOW:-}" in
    ''|*[!0-9]*) ;;
    *) [ "${#CESL_NOW}" -le 12 ] && now=$(( 10#$CESL_NOW )) ;;
esac

months=(jan feb mar apr may jun jul aug sep oct nov dec)

# ── Helpers (results in $_r — no subshells on the render path) ──────
# Strip control characters and neutralize backslashes in untrusted display
# strings — everything rendered goes through printf %b, which would otherwise
# decode escape sequences (terminal injection via branch names, paths, API
# labels, model names)
sanitize() { # string [max-length] -> $_r
    local s=$1
    s=${s//[[:cntrl:]]/}
    s=${s//\\//}
    _r=${s:0:${2:-120}}
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
        local rc=$?
        kill "$kpid" 2>/dev/null
        wait "$kpid" 2>/dev/null
        return "$rc"
    fi
}

clamp_pct() { # value -> $_r (integer 0..100, rounded)
    local v=$1 i f=""
    _r=0
    case "$v" in ''|-|null|*[!0-9.]*|*.*.*) return ;; esac
    i=${v%%.*}
    case "$v" in *.*) f=${v#*.} ;; esac
    [ -z "$i" ] && i=0
    if [ "${#i}" -gt 3 ]; then _r=100; return; fi
    i=$(( 10#$i ))
    case "$f" in [5-9]*) i=$(( i + 1 )) ;; esac
    [ "$i" -gt 100 ] && i=100
    _r=$i
}

# Escalation color for a 0-100 value: ok below warn, then warn/high/crit
state_rgb() { # pct -> $_r
    local p=$1
    if [ "$p" -ge "$CESL_CRIT" ]; then _r=$CESL_COLOR_CRIT
    elif [ "$p" -ge "$CESL_HIGH" ]; then _r=$CESL_COLOR_HIGH
    elif [ "$p" -ge "$CESL_WARN" ]; then _r=$CESL_COLOR_WARN
    else _r=$CESL_COLOR_OK
    fi
}

format_tokens() { # count -> $_r ("842", "76k", "1.0m")
    local n=$1 t
    case "$n" in ''|*[!0-9]*) n=0 ;; esac
    [ "${#n}" -gt 15 ] && n=0
    n=$(( 10#$n ))
    if [ "$n" -ge 1000000 ]; then
        t=$(( (n + 50000) / 100000 ))
        _r="$(( t / 10 )).$(( t % 10 ))m"
    elif [ "$n" -ge 1000 ]; then
        _r="$(( n / 1000 ))k"
    else
        _r=$n
    fi
}

build_bar() { # pct width rgb -> $_r (textual escape string)
    local pct=$1 width=$2 rgb=$3
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    local filled_str="" empty_str="" i
    for ((i=0; i<filled; i++)); do filled_str+="$g_fill"; done
    for ((i=0; i<empty; i++)); do empty_str+="$g_empty"; done
    _r="\033[38;2;${rgb}m${filled_str}${dim}${empty_str}${reset}"
}

# Slow path, only for a reset stamp that is not already epoch seconds (stdin
# sends epochs, and the usage digest converts ISO stamps with jq)
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
        suf=${iso_str:$(( ${#iso_str} > 6 ? ${#iso_str} - 6 : 0 ))}
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

any_to_epoch() { # epoch-seconds or ISO-8601 -> $_r; returns 1 when unusable
    local val=$1
    _r=""
    [ "${#val}" -le 64 ] || return 1
    case "$val" in
        ''|-|null) return 1 ;;
        *[!0-9]*) _r=$(iso_to_epoch "$val") || return 1 ;;
        *) [ "${#val}" -le 12 ] || return 1; _r=$(( 10#$val )) ;;
    esac
    [ -n "$_r" ]
}

fmt_epoch() { # style(time|day) epoch -> $_r ("7:05pm" | "nov 12")
    local style=$1 epoch=$2 raw="" h m mo d ap
    _r=""
    if [ "$have_tfmt" = "1" ]; then
        printf -v raw '%(%H %M %m %d)T' "$epoch" 2>/dev/null
    else
        raw=$(date -d "@$epoch" +"%H %M %m %d" 2>/dev/null) \
            || raw=$(date -j -r "$epoch" +"%H %M %m %d" 2>/dev/null)
    fi
    case "$raw" in
        [0-9][0-9]' '[0-9][0-9]' '[0-9][0-9]' '[0-9][0-9]) ;;
        *) return ;;
    esac
    h=$(( 10#${raw:0:2} )); m=${raw:3:2}; mo=$(( 10#${raw:6:2} )); d=$(( 10#${raw:9:2} ))
    case "$style" in
        time)
            ap=am
            [ "$h" -ge 12 ] && ap=pm
            h=$(( h % 12 ))
            [ "$h" -eq 0 ] && h=12
            _r="${h}:${m}${ap}"
            ;;
        day)
            [ "$mo" -ge 1 ] && [ "$mo" -le 12 ] && _r="${months[$(( mo - 1 ))]} ${d}"
            ;;
    esac
}

fmt_reset_any() { # style value(epoch-seconds or ISO-8601) -> $_r
    local style=$1
    any_to_epoch "$2" || { _r=""; return; }
    fmt_epoch "$style" "$_r"
}

# Projected utilization at the end of a rolling window, extrapolated from how
# far into it we already are. Stateless: the window opened at (reset - length),
# so the elapsed fraction is derivable from the reset stamp alone.
project_pct() { # used_pct reset_value window_seconds -> $_r (empty when quiet)
    local used=$1 val=$2 win=$3 epoch elapsed proj
    _r=""
    [ "$CESL_SHOW_PROJECTION" = "1" ] || return
    [ "$used" -gt 0 ] 2>/dev/null || return
    any_to_epoch "$val" || { _r=""; return; }
    epoch=$_r
    _r=""
    elapsed=$(( now - (epoch - win) ))
    # Extrapolating from the first few minutes of a window is noise, and a
    # negative or overrun elapsed means the stamp is not what we assumed
    [ "$elapsed" -gt $(( win / 10 )) ] 2>/dev/null || return
    [ "$elapsed" -lt "$win" ] 2>/dev/null || return
    proj=$(( used * win / elapsed ))
    [ "$proj" -gt 999 ] && proj=999
    # Quiet when healthy: only speak up when the current pace overruns
    [ "$proj" -ge "$CESL_WARN" ] 2>/dev/null || return
    [ "$proj" -ge $(( used + 5 )) ] 2>/dev/null || return
    _r=$proj
}

proj_suffix() { # projected_pct -> $_r (" ⇢ NN%" in the escalation colour)
    local p=$1 c=$1
    [ "$c" -gt 100 ] && c=100
    state_rgb "$c"
    _r=" ${dim}${g_proj}${reset} \033[38;2;${_r}m${p}%${reset}"
}

# ── Extract stdin fields (single jq) ────────────────────────────────
# One line, fields joined with the unit separator. jq does the work that used
# to cost a process per field: control characters are stripped, display
# strings are length-capped (in characters, not bytes), numbers are validated,
# and the session cost is converted and thresholded. Unlike @tsv, this does
# not escape backslashes, so a Windows cwd (C:\Users\me) survives intact.
jq_stdin='
def clean: tostring | explode | map(select(. > 31 and . != 127)) | implode;
def disp($n): clean | explode | map(if . == 92 then 47 else . end) | .[0:$n] | implode;
def num: if type == "number" then . elif type == "string" then (tonumber? // null) else null end;
def int: num | if . == null then "-" else (floor | tostring) end;
(if type == "object" then . else {} end)
| (((.cost.total_cost_usd)? // null) | num) as $cost
| ($rate | (tonumber? // 1)) as $r
| (if $cost == null or $cost < 0 then null else ($cost * $r) end) as $c
| ((.context_window.current_usage)? // null) as $cu
| (if ($cu | type) == "object"
     then ([$cu.input_tokens, $cu.cache_creation_input_tokens, $cu.cache_read_input_tokens] | map(num // 0) | add)
     else ((((.context_window.total_input_tokens)? // null) | num) // 0)
   end) as $cur
| (((.context_window.used_percentage)? // null) | num) as $up
| [
    (((.model.display_name)? // "Claude") | disp(40)),
    (((.model.id)? // "") | disp(64)),
    (((.cwd)? // (.workspace.current_dir)? // "") | clean),
    (((.version)? // "") | disp(20)),
    (((.output_style.name)? // "default") | disp(24)),
    (if $c == null then "-" else (($c * 100 + 0.5) | floor | tostring) end),
    (if $c == null then "ok"
     elif $c >= ($cc | (tonumber? // 20)) then "crit"
     elif $c >= ($cw | (tonumber? // 5)) then "warn"
     else "ok" end),
    (((.cost.total_duration_ms)? // null) | int),
    (((.cost.total_lines_added)? // null) | int),
    (((.cost.total_lines_removed)? // null) | int),
    (((.context_window.context_window_size)? // null) | int),
    ($cur | floor | tostring),
    (if $up == null then "-" else (($up + 0.5) | floor | tostring) end),
    (((.exceeds_200k_tokens)? // false) | clean),
    (((.effort.level)? // "") | disp(10)),
    (((.fast_mode)? // false) | clean),
    (((.thinking.enabled)? // false) | clean),
    (((.vim.mode)? // "") | disp(12)),
    ((((.agent)? // null) | if type == "object" then (.name // "") elif type == "string" then . else "" end) | disp(40)),
    (((.rate_limits.five_hour.used_percentage)? // (.rate_limits.five_hour.utilization)? // "") | clean | .[0:64]),
    (((.rate_limits.five_hour.resets_at)? // "") | clean | .[0:64]),
    (((.rate_limits.seven_day.used_percentage)? // (.rate_limits.seven_day.utilization)? // "") | clean | .[0:64]),
    (((.rate_limits.seven_day.resets_at)? // "") | clean | .[0:64]),
    (((.prompt_cache.requests)? // null) | int),
    (((.prompt_cache.expires_at)? // null) | int),
    (((.prompt_cache.recache_tokens_if_cold)? // null) | int),
    (((.prompt_cache.ttl)? // "") | disp(8)),
    (((.workspace.git_worktree)? // (.worktree.name)? // "") | disp(40)),
    (((((.model.display_name)? // "") | clean) + " " + (((.model.id)? // "") | clean)) | ascii_downcase | .[0:120]),
    "end"
  ]
| map(if . == "" then "-" else . end) | join("\u001f")'

read_json=$(jq -r --arg rate "$CESL_CURRENCY_RATE" --arg cw "$CESL_COST_WARN" --arg cc "$CESL_COST_CRIT" \
    "$jq_stdin" <<< "$input" 2>/dev/null)
read_json=${read_json%%$'\n'*}
read_json=${read_json%$'\r'}

# Invalid/unparseable stdin must degrade to sentinels, never to shifted or
# empty fields (those would fabricate 0% rate rows)
model_name="Claude" model_id="-" cwd="-" cc_version="-" output_style="default"
cost_cents="-" cost_level="ok" duration_ms="-" lines_added="-" lines_removed="-"
size="-" current="0" stdin_pct="-" exceeds_200k="false" effort_level="-"
fast_mode="false" thinking_on="false" vim_mode="-" agent_name="-"
sl_five_pct="-" sl_five_reset="-" sl_seven_pct="-" sl_seven_reset="-"
turn_requests="0" cache_expires="-" cache_recache="-" cache_ttl="-"
git_worktree="-" model_lc="claude"
case "$read_json" in
    *"${US}end")
        IFS="$US" read -r model_name model_id cwd cc_version output_style \
            cost_cents cost_level duration_ms lines_added lines_removed \
            size current stdin_pct exceeds_200k effort_level \
            fast_mode thinking_on vim_mode agent_name \
            sl_five_pct sl_five_reset sl_seven_pct sl_seven_reset \
            turn_requests cache_expires cache_recache cache_ttl \
            git_worktree model_lc _sentinel <<< "$read_json"
        ;;
esac

[ -z "$cwd" ] || [ "$cwd" = "null" ] || [ "$cwd" = "-" ] && cwd=$PWD
# Digits-only + length caps + base-10 forcing: leading zeros must not trip
# octal parsing, oversized values must not overflow into negatives
case "$size" in ''|0|*[!0-9]*) size=200000 ;; esac
[ "${#size}" -gt 12 ] && size=200000
size=$(( 10#$size ))
[ "$size" -eq 0 ] && size=200000
case "$current" in ''|*[!0-9]*) current=0 ;; esac
[ "${#current}" -gt 12 ] && current=0
current=$(( 10#$current ))
case "$cc_version" in ''|*[!0-9.]*) cc_version="2.1.34" ;; esac
case "$turn_requests" in ''|*[!0-9]*) turn_requests=0 ;; esac
[ "${#turn_requests}" -gt 9 ] && turn_requests=0
turn_requests=$(( 10#$turn_requests ))
case "$cache_expires" in ''|*[!0-9]*) cache_expires="" ;; esac
[ "${#cache_expires}" -gt 12 ] && cache_expires=""
case "$cache_recache" in ''|*[!0-9]*) cache_recache="" ;; esac
[ "${#cache_recache}" -gt 12 ] && cache_recache=""

# Context share: Claude Code's own figure when it sends one, so the number
# matches its UI; else the same input-only formula, rounded
case "$stdin_pct" in
    ''|*[!0-9]*) pct_used=$(( (current * 100 + size / 2) / size )) ;;
    *) [ "${#stdin_pct}" -le 4 ] && pct_used=$(( 10#$stdin_pct )) || pct_used=100 ;;
esac
format_tokens "$current"; used_fmt=$_r
format_tokens "$size";    total_fmt=$_r

# ── Model: short name + family hue ──────────────────────────────────
short_model="${model_name/Claude /}"
case "$model_lc" in
    *opus*)          model_rgb="$CESL_COLOR_OPUS" ;;
    *sonnet*)        model_rgb="$CESL_COLOR_SONNET" ;;
    *haiku*)         model_rgb="$CESL_COLOR_HAIKU" ;;
    *fable*|*mythos*) model_rgb="$CESL_COLOR_FABLE" ;;
    *)               model_rgb="$CESL_COLOR_MODEL" ;;
esac

# ── Per-turn context cost ───────────────────────────────────────────
# The API is stateless: every turn re-sends the whole context before you type
# a character. Billed at the cache-read rate, that is the real running cost,
# and the window percentage does not show it on a large window. The rate is
# per model (claude.com/pricing, November 2026); an explicit number wins.
turn_rate="$CESL_TURN_RATE"
turn_rate_src="CESL_TURN_RATE"
if [ "$turn_rate" = "auto" ]; then
    turn_rate_src="auto"
    if [ -n "$_cesl_turn_raw" ] && [ "$_cesl_turn_raw" != "auto" ]; then
        sanitize "$_cesl_turn_raw" 20
        turn_rate_src="auto (invalid CESL_TURN_RATE='$_r')"
    fi
    case "$model_lc" in
        # Right boundary: "opus-5-50" or "fable 5.10" must not match
        # Fable / Mythos 5.1 and 5.2 (not Fable 5 or Mythos 5)
        *fable-5-[12]|*fable-5-[12][!0-9]*|*"fable 5."[12]|*"fable 5."[12][!0-9]*|\
        *mythos-5-[12]|*mythos-5-[12][!0-9]*|*"mythos 5."[12]|*"mythos 5."[12][!0-9]*)
            turn_rate=0.025; turn_ppm=25000 ;;
        *opus-5-5|*opus-5-5[!0-9]*|*"opus 5.5"|*"opus 5.5"[!0-9]*|\
        *sonnet-5-5|*sonnet-5-5[!0-9]*|*"sonnet 5.5"|*"sonnet 5.5"[!0-9]*)
            turn_rate=0.05; turn_ppm=50000 ;;
        *)  turn_rate=0.1; turn_ppm=100000 ;;
    esac
fi
turn_tokens=$(( current * turn_ppm / 1000000 ))
format_tokens "$turn_tokens"; turn_fmt=$_r
ctx_tok_rgb=""
if   [ "$current" -ge "$CESL_CTX_HIGH" ]; then ctx_tok_rgb="$CESL_COLOR_CRIT"
elif [ "$current" -ge "$CESL_CTX_WARN" ]; then ctx_tok_rgb="$CESL_COLOR_WARN"
fi

# ── Prompt cache: warm until when, and what a cold turn costs ───────
# The per-turn figure above holds only while the prompt cache is warm. Once
# its TTL has passed, the next request re-writes the whole context at the
# cache-write rate instead of reading it at the cache-read rate
# (prompt_cache.*, Claude Code >= 2.1.251).
cache_cold=false
cache_until=""
recache_fmt=""
if [ "$CESL_SHOW_CACHE" = "1" ] && [ -n "$cache_expires" ]; then
    cache_expires=$(( 10#$cache_expires ))
    fmt_epoch time "$cache_expires"; cache_until=$_r
    if [ "$now" -ge "$cache_expires" ]; then
        cache_cold=true
        recache_tokens=$current
        [ -n "$cache_recache" ] && recache_tokens=$(( 10#$cache_recache ))
        format_tokens "$recache_tokens"; recache_fmt=$_r
    fi
fi

# ── Directory: last 2 components ────────────────────────────────────
dir_display() { # path -> $_r
    local dir=$1 home="${HOME:-}" nocase=0
    dir=${dir//\\//}
    home=${home//\\//}
    case "$dir" in
        [A-Za-z]:/*)
            # Windows: Claude Code sends C:/Users/me/..., Git Bash has
            # HOME=/c/Users/me — same place, and paths are case-insensitive
            case "$home" in /[A-Za-z]/*) home="${home:1:1}:${home:2}" ;; esac
            nocase=1
            ;;
    esac
    home=${home%/}
    if [ -n "$home" ]; then
        [ "$nocase" = "1" ] && shopt -s nocasematch
        if [[ "$dir" == "$home" || "$dir" == "$home"/* ]]; then
            dir="~${dir:${#home}}"
        fi
        [ "$nocase" = "1" ] && shopt -u nocasematch
    fi
    local IFS='/' parts count
    read -ra parts <<< "$dir"
    count=${#parts[@]}
    if [ "$count" -le 2 ]; then
        _r=$dir
    else
        _r="${g_ellipsis}/${parts[$((count-2))]}/${parts[$((count-1))]}"
    fi
}
dir_display "$cwd"
sanitize "$_r" 80; dirname_short=$_r

# ── Git: branch, counts, ahead/behind, worktree ─────────────────────
git_branch=""
git_staged=0
git_unstaged=0
git_untracked=0
git_remote_status=""
git_partial=false
is_worktree=false
[ "$git_worktree" != "-" ] && [ -n "$git_worktree" ] && is_worktree=true

# Walk up to the .git entry with builtins, so a directory outside any
# repository costs no git process at all
find_git_marker() { # dir -> $_r (path of the .git entry); returns 1 if none
    local d=${1//\\//} i=0
    while [ -n "$d" ] && [ "$i" -lt 64 ]; do
        if [ -e "$d/.git" ]; then _r="$d/.git"; return 0; fi
        case "$d" in
            /|[A-Za-z]:|[A-Za-z]:/) return 1 ;;
            */*) d=${d%/*}; [ -z "$d" ] && d=/ ;;
            *) return 1 ;;
        esac
        i=$(( i + 1 ))
    done
    return 1
}

if [ "$CESL_SHOW_GIT" = "1" ]; then
    git_marker=""
    if find_git_marker "$cwd"; then git_marker=$_r; fi
    if [ -n "$git_marker" ] || [ -n "${GIT_DIR:-}" ]; then
        # One call: porcelain v2 carries the branch, the upstream distance and
        # every changed path
        git_out=$(bounded2 git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch)
        git_rc=$?
        # Killed by the 2s bound: whatever arrived is incomplete — say so
        # rather than show a short count as if it were the whole tree
        [ "$git_rc" -ge 124 ] && git_partial=true
        g_oid="" g_head="" ahead=0 behind=0
        if [ -n "$git_out" ]; then
            while IFS= read -r _line; do
                case "$_line" in
                    '# branch.oid '*)  g_oid=${_line#\# branch.oid }; g_oid=${g_oid%$'\r'} ;;
                    '# branch.head '*) g_head=${_line#\# branch.head }; g_head=${g_head%$'\r'} ;;
                    '# branch.ab '*)
                        _ab=${_line#\# branch.ab }; _ab=${_ab%$'\r'}
                        ahead=${_ab%% *}; ahead=${ahead#+}
                        behind=${_ab##* }; behind=${behind#-}
                        ;;
                    [12u]' '*)
                        [ "${_line:2:1}" != "." ] && git_staged=$(( git_staged + 1 ))
                        [ "${_line:3:1}" != "." ] && git_unstaged=$(( git_unstaged + 1 ))
                        ;;
                    '? '*) git_untracked=$(( git_untracked + 1 )) ;;
                esac
            done <<< "$git_out"
        fi
        case "$g_head" in
            ''|'(detached)')
                case "$g_oid" in ''|'('*) ;; *) git_branch=${g_oid:0:7} ;; esac
                ;;
            *) git_branch=$g_head ;;
        esac
        sanitize "$git_branch" 64; git_branch=$_r
        case "$ahead" in ''|*[!0-9]*) ahead=0 ;; esac
        case "$behind" in ''|*[!0-9]*) behind=0 ;; esac
        [ "$ahead" -gt 0 ] 2>/dev/null && git_remote_status+="${g_ahead}${ahead}"
        [ "$behind" -gt 0 ] 2>/dev/null && git_remote_status+="${g_behind}${behind}"

        # Older Claude Code does not send workspace.git_worktree: a linked
        # worktree has a .git *file* that points into <repo>/.git/worktrees/
        if ! $is_worktree && [ -n "$git_marker" ] && [ -f "$git_marker" ]; then
            _gl=""
            IFS= read -r _gl < "$git_marker" 2>/dev/null
            case "$_gl" in gitdir:*/worktrees/*) is_worktree=true ;; esac
        fi
    fi
fi

# ── Session duration (cost.total_duration_ms) ───────────────────────
session_duration=""
case "$duration_ms" in
    ''|-|null|*[!0-9]*) ;;
    *)
        ms_int=$duration_ms
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

# ── Session cost (converted and thresholded by jq, in cents) ────────
cost_fmt=""
cost_rgb=""
case "$cost_cents" in
    ''|-|*[!0-9]*) ;;
    *)
        if [ "${#cost_cents}" -le 15 ]; then
            cost_cents=$(( 10#$cost_cents ))
            printf -v cost_fmt '%d.%02d' $(( cost_cents / 100 )) $(( cost_cents % 100 ))
            case "$cost_level" in
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
        _c=$pct_used; [ "$_c" -gt 100 ] && _c=100
        state_rgb "$_c"
        ctx="\033[38;2;${_r}m${pct_used}%${reset} ${dim}(${used_fmt}/${total_fmt})${reset}"
        [ "$pct_used" -ge "$CESL_HIGH" ] && ctx="${alert}${g_warn}${reset} ${ctx}"
    else
        ctx="${c_txt}${pct_used}%${reset} ${dim}(${used_fmt}/${total_fmt})${reset}"
    fi
    [ "$exceeds_200k" = "true" ] && ctx+=" ${alert}${g_warn} 200k+${reset}"
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
        $git_partial && dseg+=" ${c_warn}${g_ellipsis}${reset}"
        [ -n "$git_remote_status" ] && dseg+=" ${dim}${git_remote_status}${reset}"
        dseg+="${dim})${reset}"
    fi
    $is_worktree && dseg+=" ${dim}${g_wt}${reset}"
    seg "$dseg"
fi

# Metrics group: cost · duration · lines · per-turn · effort · badges
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

# Per-turn cost, and the request count that multiplies it (Claude Code >= 2.1.251).
# With a cold cache the cache-read figure would be a lie: show what the next
# turn re-writes instead.
if [ "$CESL_SHOW_TURN" = "1" ] && [ "$current" -ge 1000 ]; then
    if $cache_cold; then
        if [ "$recache_tokens" -ge "$CESL_CTX_WARN" ]; then
            madd "${alert}${recache_fmt} next turn${reset} ${dim}(cache cold)${reset}"
        else
            madd "${dim}${recache_fmt} next turn (cache cold)${reset}"
        fi
    elif [ -n "$ctx_tok_rgb" ]; then
        madd "\033[38;2;${ctx_tok_rgb}m${turn_fmt}/turn${reset}"
    else
        madd "${dim}${turn_fmt}/turn${reset}"
    fi
    [ "$turn_requests" -gt 0 ] && madd "${dim}${turn_requests}t${reset}"
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

# ── OAuth token resolution (enrichment only; background fetch) ──────
get_oauth_token() {
    if [ -n "$CLAUDE_CODE_OAUTH_TOKEN" ]; then
        echo "$CLAUDE_CODE_OAUTH_TOKEN"
        return 0
    fi
    local creds_file="${HOME}/.claude/.credentials.json"
    if [ -f "$creds_file" ]; then
        local token
        token=$(jq -r '.claudeAiOauth.accessToken // empty' "$creds_file" 2>/dev/null)
        token=${token%$'\r'}
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

# ── Usage API (extra usage + scoped limits only) ────────────────────
# Stale-while-revalidate. A render only ever reads a small pre-digested file
# (shell builtins, no process). When that digest is older than the TTL, one
# detached background job refreshes it for the next render. The request can
# take seconds, and Claude Code cancels a render that is still running when
# the next update arrives: a fetch on the render path would get killed
# mid-write and delay every other segment.
#
# A usage payload is valid when it is an object with at least one non-null
# known section (an error body has none, so it is never cached).
# Do not require five_hour: verified Ultra accounts have no 5-hour limit
# (since 2026-10-30), and a null five_hour must not throw away the
# per-model and extra-usage data that comes with it.
#
# Digest: line 1 "cesl1 <fetch-epoch>", then one line per row:
#   scoped <label> <percent> <reset-epoch> <is_active 0|1>
#   extra  <percent> <used-cents> <limit-cents>
# A scoped limit that the API marks inactive is kept when it has usage: the
# Fable weekly allowance is reported that way, and it is real consumption.
usage_jq_digest='
def clean: tostring | explode | map(select(. > 31 and . != 127)) | implode;
def num: if type == "number" then . elif type == "string" then (tonumber? // null) else null end;
def epoch: . as $s
  | if type == "number" then (floor | tostring)
    elif type == "string" then
      (try ($s | sub("\\.[0-9]+"; "") | sub("(Z|\\+00:00)$"; "Z") | fromdateiso8601 | floor | tostring)
       catch ($s | clean))
    else "-" end;
if (type == "object" and ([.five_hour, .seven_day, .limits, .extra_usage] | any(. != null))) then
  (["cesl1", $now] | join("\u001f")),
  ( ((.limits)? // [])
    | (if type == "array" then . else [] end)
    | map(select(type == "object" and (((.kind)? // "") == "weekly_scoped")))
    | map(select(((.is_active)? != false) or ((((.percent)? // 0) | (num // 0)) > 0)))
    | .[0:8][]
    | [ "scoped",
        (((.scope.model.display_name)? // (.scope.model.id)? // (.group)? // "model")
          | clean | explode | map(if . == 92 then 47 else . end) | implode | ascii_downcase | .[0:40]),
        (((.percent)? // 0) | clean | .[0:12]),
        (((.resets_at)? // "-") | epoch | .[0:64]),
        (if (.is_active)? == false then "0" else "1" end)
      ]
    | map(if . == "" then "-" else . end) | join("\u001f") ),
  ( ((.extra_usage)? // null) as $e
    | if ($e | type) == "object" and $e.is_enabled == true then
        [ "extra",
          (($e.utilization // 0) | clean | .[0:12]),
          (((($e.used_credits | num) // 0) + 0.5) | floor | tostring),
          (((($e.monthly_limit | num) // 0) + 0.5) | floor | tostring)
        ] | join("\u001f")
      else empty end )
else error("not a usage payload") end'

cache_dir="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/claude-statusline-${UID:-$(id -u)}"
cache_file="$cache_dir/usage-cache.json"
digest_file="$cache_dir/usage-digest"
fail_marker="$cache_dir/usage-fail"
lock_file="$cache_dir/fetch.lck"
tmp_raw="$cache_file.$$"
tmp_dig="$digest_file.$$"
usage_rows=()
usage_state="off"      # off | none | fresh | stale
usage_age=""
usage_fetch="not needed"

load_digest() { # fills usage_rows / usage_state / usage_age from the digest
    local magic="" epoch="" line n=0
    usage_rows=()
    usage_state="none"
    usage_age=""
    [ -f "$digest_file" ] && [ ! -L "$digest_file" ] || return 1
    {
        IFS="$US" read -r magic epoch
        while [ "$n" -lt 10 ] && IFS= read -r line; do
            [ "${#line}" -le 400 ] && usage_rows[n]=${line%$'\r'}
            n=$(( n + 1 ))
        done
    } < "$digest_file" 2>/dev/null
    epoch=${epoch%$'\r'}
    case "$epoch" in ''|*[!0-9]*) epoch="" ;; esac
    if [ "$magic" != "cesl1" ] || [ -z "$epoch" ] || [ "${#epoch}" -gt 12 ]; then
        usage_rows=()
        return 1
    fi
    usage_age=$(( now - 10#$epoch ))
    if [ "$usage_age" -ge 0 ] && [ "$usage_age" -lt "$CESL_CACHE_TTL" ]; then
        usage_state="fresh"
    elif [ "$usage_age" -gt -86400 ] && [ "$usage_age" -lt 86400 ]; then
        # Stale-cache grace is bounded: reuse at most 24h-old data, never
        # indefinitely (token removed, API gone)
        usage_state="stale"
    else
        usage_rows=()
    fi
}

# Negative cache: after a failed fetch, back off for one TTL instead of
# starting a job (token resolution + curl) on every render
recent_failure() {
    local t=""
    [ -f "$fail_marker" ] && [ ! -L "$fail_marker" ] || return 1
    IFS= read -r t < "$fail_marker" 2>/dev/null
    t=${t%$'\r'}
    case "$t" in ''|*[!0-9]*) return 1 ;; esac
    [ "${#t}" -le 12 ] || return 1
    t=$(( now - 10#$t ))
    [ "$t" -ge 0 ] && [ "$t" -lt "$CESL_CACHE_TTL" ]
}

# Single-flight lock: concurrent sessions must not stampede the API when the
# shared digest expires. An exclusive create (noclobber) is atomic and needs
# no process; a lock older than 30s is a dead job and is taken over.
acquire_lock() {
    local t=""
    set -o noclobber
    if { printf '%s\n' "$now" > "$lock_file"; } 2>/dev/null; then
        set +o noclobber
        return 0
    fi
    set +o noclobber
    [ -f "$lock_file" ] && [ ! -L "$lock_file" ] || return 1
    IFS= read -r t < "$lock_file" 2>/dev/null
    t=${t%$'\r'}
    case "$t" in ''|*[!0-9]*) t=0 ;; esac
    [ "${#t}" -gt 12 ] && t=0
    if [ $(( now - 10#$t )) -gt 30 ]; then
        { printf '%s\n' "$now" > "$lock_file"; } 2>/dev/null && return 0
    fi
    return 1
}

fetch_cleanup() { rm -f "$tmp_raw" "$tmp_dig" "$lock_file" 2>/dev/null; }

fetch_usage() { # holds the lock; runs detached (in the foreground for explain)
    local token response dig ok=0
    chmod 700 "$cache_dir" 2>/dev/null
    # Leftovers of fetches that were cancelled mid-write (versions before
    # 2.3.0 fetched on the render path)
    set +f
    rm -f "$cache_dir"/usage-cache.json.[0-9]* "$cache_dir"/usage-digest.[0-9]* 2>/dev/null
    set -f
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
        if [ -n "$response" ]; then
            # One jq validates the payload and digests it; an error body
            # fails the validation and reaches neither file
            dig=$(printf '%s' "$response" | jq -r --arg now "$now" "$usage_jq_digest" 2>/dev/null)
            dig=${dig//$'\r'/}
            case "$dig" in
                "cesl1${US}"*)
                    printf '%s\n' "$response" > "$tmp_raw" && mv -f "$tmp_raw" "$cache_file" \
                        && printf '%s\n' "$dig" > "$tmp_dig" && mv -f "$tmp_dig" "$digest_file" \
                        && ok=1
                    ;;
            esac
        fi
    fi
    if [ "$ok" = "1" ]; then
        rm -f "$fail_marker" 2>/dev/null
        usage_fetch="refreshed"
    else
        printf '%s\n' "$now" > "$fail_marker" 2>/dev/null
        usage_fetch="failed (no token, API unreachable, or an invalid payload)"
    fi
    fetch_cleanup
}

# The API only feeds the scoped-weekly and extra-usage rows. With both hidden
# there is nothing to enrich, so skip the cache and the request entirely.
usage_needed=0
if [ "$CESL_SHOW_RATE_BLOCK" = "1" ] \
   && { [ "$CESL_SHOW_SCOPED" = "1" ] || [ "$CESL_SHOW_EXTRA" = "1" ]; }; then
    usage_needed=1
fi

if [ "$usage_needed" = "1" ]; then
    [ -d "$cache_dir" ] || mkdir -m 700 -p "$cache_dir" 2>/dev/null
    if [ ! -d "$cache_dir" ] || [ -L "$cache_dir" ] || [ ! -O "$cache_dir" ]; then
        # Not ours: no cache, so no enrichment (never write into it)
        usage_state="none"
        usage_fetch="skipped (cache directory unusable: $cache_dir)"
    else
        load_digest
        if [ "$usage_state" = "fresh" ]; then
            usage_fetch="not needed (digest is fresh)"
        elif recent_failure; then
            usage_fetch="skipped (a fetch failed less than ${CESL_CACHE_TTL}s ago)"
        elif ! acquire_lock; then
            usage_fetch="skipped (another session is fetching)"
        elif [ "$mode" = "explain" ]; then
            fetch_usage
            load_digest
        else
            usage_fetch="started in the background"
            ( trap fetch_cleanup EXIT; trap 'exit 0' TERM INT HUP; fetch_usage ) </dev/null >/dev/null 2>&1 &
        fi
    fi
fi

# ── Rate-limit block ────────────────────────────────────────────────
rate_lines=""

rate_row() { # label pct reset_style reset_val [value_text]
    local label=$1 pct=$2 style=$3 rval=$4 vtext=$5
    local rgb bar pfmt line
    state_rgb "$pct"; rgb=$_r
    build_bar "$pct" "$CESL_BAR_WIDTH" "$rgb"; bar=$_r
    printf -v line '%-7.7s' "$label"
    line="${c_txt}${line}${reset} ${bar}"
    if [ -n "$vtext" ]; then
        line+=" ${vtext}"
    else
        printf -v pfmt '%3d' "$pct"
        line+=" \033[38;2;${rgb}m${pfmt}%${reset}"
    fi
    fmt_reset_any "$style" "$rval"
    [ -n "$_r" ] && line+=" ${dim}${g_reset}${reset} ${c_txt}${_r}${reset}"
    [ -n "$rate_lines" ] && rate_lines+="\n"
    rate_lines+="$line"
}

five_proj="" seven_proj=""
if [ "$CESL_SHOW_RATE_BLOCK" = "1" ]; then
    # 5-hour / 7-day: stdin is authoritative
    # A 0% window with no reset stamp is a stub, not a window (no 5-hour
    # limit on verified Ultra accounts): do not draw an empty row for it
    if [ "$sl_five_pct" != "-" ]; then
        clamp_pct "$sl_five_pct"; five_pct=$_r
        if [ "$sl_five_reset" != "-" ] || [ "$five_pct" != "0" ]; then
            rate_row "5-hour" "$five_pct" time "$sl_five_reset"
            project_pct "$five_pct" "$sl_five_reset" 18000; five_proj=$_r
            if [ -n "$five_proj" ]; then proj_suffix "$five_proj"; rate_lines+=$_r; fi
        fi
    fi
    if [ "$sl_seven_pct" != "-" ]; then
        clamp_pct "$sl_seven_pct"; seven_pct=$_r
        rate_row "7-day" "$seven_pct" day "$sl_seven_reset"
        project_pct "$seven_pct" "$sl_seven_reset" 604800; seven_proj=$_r
        if [ -n "$seven_proj" ]; then proj_suffix "$seven_proj"; rate_lines+=$_r; fi
    fi

    for _row in "${usage_rows[@]}"; do
        _kind="" _a="" _b="" _c="" _d=""
        IFS="$US" read -r _kind _a _b _c _d <<< "$_row"
        case "$_kind" in
            scoped)
                # Per-model scoped weekly limits (undocumented limits[]; defensive)
                [ "$CESL_SHOW_SCOPED" = "1" ] || continue
                [ -z "$_a" ] || [ "$_a" = "-" ] && continue
                sanitize "$_a" 40; _a=$_r
                clamp_pct "$_b"
                rate_row "$_a" "$_r" day "$_c"
                ;;
            extra)
                # Extra usage (credits) — only present when enabled on the account
                [ "$CESL_SHOW_EXTRA" = "1" ] || continue
                case "$_b" in ''|*[!0-9]*) _b=0 ;; esac
                case "$_c" in ''|*[!0-9]*) _c=0 ;; esac
                [ "${#_b}" -gt 15 ] && _b=0
                [ "${#_c}" -gt 15 ] && _c=0
                _b=$(( 10#$_b )); _c=$(( 10#$_c ))
                clamp_pct "$_a"; extra_pct=$_r
                printf -v extra_used '%d.%02d' $(( _b / 100 )) $(( _b % 100 ))
                printf -v extra_limit '%d.%02d' $(( _c / 100 )) $(( _c % 100 ))
                state_rgb "$extra_pct"
                extra_val="\033[38;2;${_r}m${CESL_CURRENCY_SYMBOL}${extra_used}${reset}${dim}/${reset}${c_txt}${CESL_CURRENCY_SYMBOL}${extra_limit}${reset}"
                rate_row "extra" "$extra_pct" none "" "$extra_val"
                # Credits reset on the first day of next month
                _mo=""
                if [ "$have_tfmt" = "1" ]; then
                    printf -v _mo '%(%m)T' "$now" 2>/dev/null
                else
                    _mo=$(date +%m 2>/dev/null)
                fi
                case "$_mo" in
                    [0-9][0-9])
                        _mo=$(( 10#$_mo % 12 ))
                        rate_lines+=" ${dim}${g_reset}${reset} ${c_txt}${months[$_mo]} 1${reset}"
                        ;;
                esac
                ;;
        esac
    done
fi

# ── Context hint ────────────────────────────────────────────────────
# Says what to do, and picks the right command: /compact reclaims room in a
# window that is nearly full, /clear is the answer to a session that is merely
# expensive — a 486k session on a 1M window is only half full and still costs
# 48k a turn at a 10% cache-read rate. A cold cache changes the sum for one
# turn: the whole context is written again.
hint_line=""
if [ "$CESL_SHOW_HINT" = "1" ]; then
    if [ "$pct_used" -ge "$CESL_HIGH" ]; then
        hint_line="${alert}${g_warn}${reset} ${c_txt}${pct_used}% of the window used ${dim}—${reset} ${c_txt}/compact now, or /clear if you have switched task${reset}"
    elif $cache_cold && [ "$recache_tokens" -ge "$CESL_CTX_WARN" ]; then
        hint_line="${alert}${g_warn}${reset} ${c_txt}prompt cache expired${cache_until:+ at ${cache_until}} ${dim}—${reset} ${c_txt}the next turn re-writes ${recache_fmt} at the cache-write rate, not ~${turn_fmt} ${dim}—${reset} ${c_txt}/clear first if you have switched task${reset}"
    elif [ "$current" -ge "$CESL_CTX_HIGH" ]; then
        hint_line="${alert}${g_warn}${reset} ${c_txt}${used_fmt} context ${dim}—${reset} ${c_txt}every turn re-sends it, ~${turn_fmt} at the cache rate, before you type ${dim}—${reset} ${c_txt}/clear between tasks${reset}"
        [ -n "$cache_until" ] && hint_line+=" ${dim}${g_dot} cache warm until ${cache_until}${reset}"
    fi
fi

# ── Explain mode ────────────────────────────────────────────────────
if [ "$mode" = "explain" ]; then
    echo "Claude Epic Status Line $cesl_version — explain"
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
    sanitize "$cwd" 200
    echo "model:        $model_name (id: $model_id, family rgb: $model_rgb)"
    echo "version:      $cc_version"
    echo "cwd:          $_r (shown as: $dirname_short)"
    echo "context:      $current/$size tokens ($pct_used%, stdin used_percentage=$stdin_pct), exceeds_200k=$exceeds_200k"
    echo "per turn:     $turn_tokens tokens ($turn_fmt at rate $turn_rate, source: $turn_rate_src), requests=$turn_requests"
    if [ -n "$cache_expires" ]; then
        echo "prompt cache: ttl=$cache_ttl expires_at=$cache_expires (${cache_until:-n/a}), $($cache_cold && echo "COLD: the next turn re-writes ${recache_fmt}" || echo "warm for $(( cache_expires - now ))s"), recache_tokens_if_cold=${cache_recache:-n/a} (CESL_SHOW_CACHE=$CESL_SHOW_CACHE)"
    else
        echo "prompt cache: no expiry in stdin (Claude Code < 2.1.251, no API response yet, caching off, or CESL_SHOW_CACHE=0)"
    fi
    echo "ctx thresh:   warn=$CESL_CTX_WARN high=$CESL_CTX_HIGH tokens"
    echo "colour:       $([ "$cesl_color" = "1" ] && echo enabled || echo disabled) (CESL_COLOR=$CESL_COLOR, NO_COLOR=${NO_COLOR:-unset}, TERM=${TERM:-unset})"
    echo "cost:         display=${cost_fmt:-n/a} ${CESL_CURRENCY_SYMBOL} (rate $CESL_CURRENCY_RATE, level $cost_level)"
    echo "duration:     raw_ms=$duration_ms display=${session_duration:-n/a}"
    echo "lines:        +$lines_added/-$lines_removed"
    echo "effort:       $effort_level | fast: $fast_mode | thinking: $thinking_on | vim: $vim_mode"
    echo "output_style: $output_style | agent: $agent_name"
    echo "git:          branch=${git_branch:-n/a} S=$git_staged U=$git_unstaged A=$git_untracked remote=$git_remote_status worktree=$is_worktree timed_out=$git_partial"
    sanitize "$sl_five_pct" 20; _p5=$_r
    sanitize "$sl_five_reset" 40; _r5=$_r
    sanitize "$sl_seven_pct" 20; _p7=$_r
    sanitize "$sl_seven_reset" 40
    echo "stdin limits: 5h=${_p5}% reset=${_r5} | 7d=${_p7}% reset=$_r"
    [ "$sl_five_pct" = "-" ] && [ "$sl_seven_pct" != "-" ] && echo "              no 5-hour data with a 7-day window: expected on a verified Ultra account (no 5-hour limit)"
    echo "projection:   5h=${five_proj:-n/a} | 7d=${seven_proj:-n/a} (CESL_SHOW_PROJECTION=$CESL_SHOW_PROJECTION)"
    echo "bash:         $BASH_VERSION (time builtin: $have_tfmt)"
    echo
    echo "== usage api =="
    echo "needed:       $usage_needed (scoped=$CESL_SHOW_SCOPED extra=$CESL_SHOW_EXTRA rate_block=$CESL_SHOW_RATE_BLOCK)"
    echo "digest:       $usage_state${usage_age:+, ${usage_age}s old} (ttl ${CESL_CACHE_TTL}s, ${#usage_rows[@]} row(s)) — $digest_file"
    echo "fetch:        $usage_fetch"
    if [ "$usage_needed" = "1" ] && [ -f "$cache_file" ] && [ ! -L "$cache_file" ]; then
        echo "last payload: $cache_file"
        jq '{five_hour, seven_day, extra_usage, limits}' "$cache_file" 2>/dev/null
    else
        echo "last payload: none (no token, API unreachable, or both CESL_SHOW_SCOPED and CESL_SHOW_EXTRA are 0)"
    fi
    echo
    echo "== config =="
    set | grep '^CESL_' | sort
    exit 0
fi

# ── Output ──────────────────────────────────────────────────────────
out="$line1"
[ -n "$rate_lines" ] && out+="\n\n${rate_lines}"
[ -n "$hint_line" ] && out+="\n\n${hint_line}"

if [ "$cesl_color" != "1" ]; then
    # Single strip point: no segment can leak colour past the gate
    out=${out//\\033\[*([0-9;])m/}
fi
printf "%b" "$out"

exit 0

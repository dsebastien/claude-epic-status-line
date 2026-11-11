#!/usr/bin/env bash
# Test suite for statusline.sh.
#
#   bash tests/run.sh                      # run with the bash on PATH
#   CESL_TEST_BASH=/bin/bash tests/run.sh  # pick the interpreter (macOS: bash 3.2)
#
# Everything runs against a throwaway HOME and TMPDIR, with a fixed clock
# (CESL_NOW) and a fake curl, so no test touches your configuration, your
# usage cache or the network. Needs jq and git, like the script itself.
set -u

HERE=$(cd "$(dirname "$0")" && pwd)
SL="$HERE/../statusline.sh"
FIX="$HERE/fixtures"
SH="${CESL_TEST_BASH:-bash}"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/cesl-test.XXXXXX") || exit 1
WORK_POSIX=$WORK   # for PATH, where a drive letter's colon would split the entry
# Git Bash: native programs (jq, git) receive C:/... for a /tmp/... argument,
# so use that one form everywhere
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) command -v cygpath >/dev/null 2>&1 && WORK=$(cygpath -m "$WORK") ;;
esac
trap 'rm -rf "$WORK_POSIX"' EXIT

# Start from a clean environment: no CESL_* override, no real token
for _v in ${!CESL_@}; do unset "$_v"; done
unset CLAUDE_CODE_OAUTH_TOKEN GIT_DIR XDG_RUNTIME_DIR
export HOME="$WORK/home"
export TMPDIR="$WORK/tmp"
export CESL_CONFIG="$WORK/no-config.sh"
export CESL_NOW=1794386000      # 2026-11-11 08:33:20 UTC
export TZ=UTC
export NO_COLOR=1
mkdir -p "$HOME" "$TMPDIR" "$WORK/bin" "$WORK/plain"

# Usage rows are off unless a test turns them on, so nothing fetches by accident
export CESL_SHOW_SCOPED=0 CESL_SHOW_EXTRA=0

BUDGET=20   # update on purpose, with the reason in the commit message
pass=0
fail=0
ok()   { pass=$(( pass + 1 )); }
ko()   { fail=$(( fail + 1 )); printf 'FAIL  %s\n      %s\n' "$1" "$2"; }
has()  { case "$2" in *"$3"*) ok ;; *) ko "$1" "expected to find: $3 — in: $2" ;; esac; }
hasnt() { case "$2" in *"$3"*) ko "$1" "expected NOT to find: $3 — in: $2" ;; *) ok ;; esac; }
is()   { if [ "$2" = "$3" ]; then ok; else ko "$1" "expected: $3 — got: $2"; fi; }

payload() { jq -c "$@" "$FIX/base.json"; }          # base fixture + a jq edit
render()  { printf '%s' "$1" | "$SH" "$SL"; }       # json -> rendered text
explain() { printf '%s' "$1" | "$SH" "$SL" explain; }
line1()   { printf '%s\n' "$1" | head -n 1; }
cache_dir() { printf '%s' "$TMPDIR/claude-statusline-$(id -u)"; }

echo "statusline.sh tests — $("$SH" -c 'echo "bash $BASH_VERSION"'), $(jq --version), $(uname -s)"

# ── Basics ──────────────────────────────────────────────────────────
base=$(payload '.cwd = $d' --arg d "$WORK/plain")
out=$(render "$base")
has "model name"            "$out" "Opus 5.5 │"
has "context from stdin"    "$out" "38% (76k/200k)"
has "cost"                  "$out" '$3.46'
has "duration"              "$out" "1h31m"
has "lines"                 "$out" "+156/-23"
has "per-turn at 5%"        "$out" "3k/turn"
has "request count"         "$out" "88t"
has "effort"                "$out" "◑ medium"
has "thinking badge"        "$out" "think"
hasnt "no hint below 120k"  "$out" "context —"
hasnt "no 200k alert"       "$out" "200k+"
hasnt "no colour escapes"   "$out" $'\033'
is "version subcommand" "$("$SH" "$SL" version | cut -d' ' -f1-4)" "Claude Epic Status Line"
is "empty stdin"        "$(printf '' | "$SH" "$SL")" "Claude"

out=$(render 'this is not json')
has "invalid JSON degrades"         "$out" "Claude │ 0% (0/200k)"
hasnt "invalid JSON draws no rows"  "$out" "7-day"

out=$(render '[1,2,3]')
has "non-object JSON degrades" "$out" "Claude │ 0% (0/200k)"

out=$(render "$(payload '.cwd = $d | .model = "x" | .cost = 5 | .context_window = [] | .rate_limits = "no"' --arg d "$WORK/plain")")
has "wrong types degrade" "$out" "Claude │ 0% (0/200k)"

# ── Context share ───────────────────────────────────────────────────
out=$(render "$(payload '.cwd = $d | .context_window.used_percentage = null' --arg d "$WORK/plain")")
has "computed share when stdin has none" "$out" "38% (76k/200k)"
out=$(render "$(payload '.cwd = $d | .context_window.used_percentage = 85.6' --arg d "$WORK/plain")")
has "share is rounded"        "$out" "86% (76k/200k)"
has "compact hint at 80%+"    "$out" "86% of the window used"
out=$(render "$(payload '.cwd = $d | .context_window.current_usage = null' --arg d "$WORK/plain")")
has "falls back to total_input_tokens" "$out" "(76k/200k)"
out=$(render "$(payload '.cwd = $d | .exceeds_200k_tokens = true' --arg d "$WORK/plain")")
has "200k alert" "$out" "200k+"

# ── Directory display ───────────────────────────────────────────────
out=$(line1 "$(render "$(payload '.cwd = $d' --arg d "$HOME/proj")")")
has "home is abbreviated" "$out" "│ ~/proj │"
out=$(line1 "$(render "$(payload '.cwd = $d' --arg d "$HOME/a/b/c")")")
has "last two components" "$out" "│ …/b/c │"

# Windows: Claude Code sends backslashes, Git Bash has HOME=/c/Users/me
winhome() { printf '%s' "$1" | HOME=/c/Users/me "$SH" "$SL"; }
out=$(line1 "$(winhome "$(payload '.cwd = "C:\\Users\\me\\My Drive\\Notes\\Vault"')")")
has   "windows path: last two components" "$out" "│ …/Notes/Vault │"
hasnt "windows path: no doubled slashes"  "$out" "//"
out=$(line1 "$(winhome "$(payload '.cwd = "C:\\Users\\me\\proj"')")")
has "windows path: home is abbreviated" "$out" "│ ~/proj │"
out=$(line1 "$(winhome "$(payload '.cwd = "c:\\users\\ME\\proj"')")")
has "windows path: case-insensitive home" "$out" "│ ~/proj │"

# ── Per-turn rate ───────────────────────────────────────────────────
big='.cwd = $d | .context_window.context_window_size = 1000000 | .context_window.used_percentage = 49
     | .context_window.current_usage = {input_tokens: 0, cache_creation_input_tokens: 0, cache_read_input_tokens: 486000}
     | .prompt_cache.recache_tokens_if_cold = 486000'
out=$(render "$(payload "$big" --arg d "$WORK/plain")")
has "opus 5.5 reads cache at 5%" "$out" "24k/turn"
has "hint above 120k"            "$out" "486k context — every turn re-sends it, ~24k at the cache rate"
has "hint names the cache expiry" "$out" "cache warm until 9:28am"
out=$(render "$(payload "$big | .model = {id: \"claude-fable-5-2\", display_name: \"Fable 5.2\"}" --arg d "$WORK/plain")")
has "fable 5.2 reads cache at 2.5%" "$out" "12k/turn"
out=$(render "$(payload "$big | .model = {id: \"claude-fable-5\", display_name: \"Fable 5\"}" --arg d "$WORK/plain")")
has "fable 5 reads cache at 10%" "$out" "48k/turn"
out=$(render "$(payload "$big | .model = {id: \"claude-opus-5-50\", display_name: \"Opus 5.50\"}" --arg d "$WORK/plain")")
has "opus-5-50 is not opus 5.5" "$out" "48k/turn"
out=$(printf '%s' "$(payload "$big" --arg d "$WORK/plain")" | CESL_TURN_RATE=0.5 "$SH" "$SL")
has "explicit rate wins" "$out" "243k/turn"
out=$(printf '%s' "$(payload "$big" --arg d "$WORK/plain")" | CESL_TURN_RATE=1.2.3 "$SH" "$SL")
has "invalid rate falls back to auto" "$out" "24k/turn"
out=$(printf '%s' "$(payload "$big" --arg d "$WORK/plain")" | CESL_TURN_RATE=5 "$SH" "$SL")
has "rate above 1 falls back to auto" "$out" "24k/turn"

# ── Prompt cache ────────────────────────────────────────────────────
cold=$(payload "$big | .prompt_cache.expires_at = 1794385000" --arg d "$WORK/plain")
out=$(render "$cold")
has   "cold cache: next-turn cost"  "$out" "486k next turn (cache cold)"
hasnt "cold cache: no cache-read figure in the metrics" "$(line1 "$out")" "/turn"
has   "cold cache: hint"            "$out" "prompt cache expired at 8:16am — the next turn re-writes 486k at the cache-write rate, not ~24k"
out=$(printf '%s' "$cold" | CESL_SHOW_CACHE=0 "$SH" "$SL")
has   "CESL_SHOW_CACHE=0 keeps the cache-read figure" "$out" "24k/turn"
hasnt "CESL_SHOW_CACHE=0 hides the expiry"            "$out" "cache warm"
hasnt "CESL_SHOW_CACHE=0 hides the cold state"        "$out" "cache cold"
out=$(render "$(payload "$big | del(.prompt_cache)" --arg d "$WORK/plain")")
has   "no prompt_cache: plain per-turn" "$out" "24k/turn"
hasnt "no prompt_cache: no expiry"      "$out" "cache warm"

# ── Rate rows and projection ────────────────────────────────────────
out=$(render "$base")
has "5-hour row"        "$out" "5-hour  ████░░░░░░  42% ⟳ 11:00am ⇢ 82%"
has "7-day row"         "$out" "7-day   █████████░  94% ⟳ nov 12 ⇢ 118%"
out=$(render "$(payload '.cwd = $d | del(.rate_limits.five_hour)' --arg d "$WORK/plain")")
hasnt "ultra: no 5-hour row" "$out" "5-hour"
has   "ultra: 7-day row"     "$out" "7-day"
out=$(render "$(payload '.cwd = $d | del(.rate_limits)' --arg d "$WORK/plain")")
hasnt "no rate_limits: no rows" "$out" "7-day"
out=$(printf '%s' "$base" | CESL_SHOW_PROJECTION=0 "$SH" "$SL")
hasnt "projection off" "$out" "⇢"
out=$(printf '%s' "$base" | CESL_SHOW_RATE_BLOCK=0 "$SH" "$SL")
hasnt "rate block off" "$out" "7-day"
out=$(printf '%s' "$base" | CESL_GLYPHS=ascii CESL_BAR_WIDTH=5 "$SH" "$SL")
has "ascii glyphs" "$out" "7-day   ####.  94% ~ nov 12 -> 118%"

# ── Cost ────────────────────────────────────────────────────────────
out=$(printf '%s' "$base" | CESL_CURRENCY_SYMBOL='€' CESL_CURRENCY_RATE=0.5 "$SH" "$SL")
has "currency conversion" "$out" "€1.73"
out=$(render "$(payload '.cwd = $d | .cost.total_cost_usd = 0' --arg d "$WORK/plain")")
hasnt "zero cost is hidden" "$out" '$0.00'

# ── Terminal safety ─────────────────────────────────────────────────
evil=$(payload '.cwd = $d | .model.display_name = "Evil\u001b[31m\\033[41mX\u0007" | .agent = {name: "a\\033]0;pwn\u0007"}' --arg d "$WORK/plain")
out=$(printf '%s' "$evil" | CESL_COLOR=1 "$SH" "$SL")
hasnt "no raw control characters from input" "$out" $'\007'
hasnt "no decoded escape from input"         "$out" $'\033[41m'
hasnt "no OSC from input"                    "$out" $'\033]0'
has   "backslashes are neutralized"          "$out" "/033[41mX"

# ── Git ─────────────────────────────────────────────────────────────
g() { git -C "$WORK/repo" -c user.name=t -c user.email=t@example.com -c commit.gpgsign=false "$@" >/dev/null 2>&1; }
mkdir -p "$WORK/repo" "$WORK/origin.git"
git -C "$WORK/origin.git" init -q --bare
g init -q
g checkout -q -b main
echo one > "$WORK/repo/a.txt"; echo one > "$WORK/repo/b.txt"
g add -A; g commit -q -m first
g remote add origin "$WORK/origin.git"
g push -q -u origin main
echo two > "$WORK/repo/c.txt"; g add c.txt; g commit -q -m second     # ahead 1
echo staged > "$WORK/repo/a.txt"; g add a.txt                         # staged
echo dirty > "$WORK/repo/b.txt"                                       # unstaged
echo new > "$WORK/repo/n1.txt"; echo new > "$WORK/repo/n2.txt"        # untracked x2
mkdir -p "$WORK/repo/sub dir"
out=$(line1 "$(render "$(payload '.cwd = $d' --arg d "$WORK/repo")")")
has "git: branch and counts" "$out" "(main S:1 U:1 A:2 ⇡1)"
out=$(line1 "$(render "$(payload '.cwd = $d' --arg d "$WORK/repo/sub dir")")")
has "git: from a subdirectory with a space" "$out" "(main S:1 U:1 A:2 ⇡1)"
out=$(line1 "$(printf '%s' "$(payload '.cwd = $d' --arg d "$WORK/repo")" | CESL_SHOW_GIT=0 "$SH" "$SL")")
hasnt "git: off" "$out" "(main"
out=$(line1 "$(render "$base")")
has "git: not a repository" "$out" "/plain │"

g stash -q -u
g worktree add -q "$WORK/wt" -b feature/x
out=$(line1 "$(render "$(payload '.cwd = $d' --arg d "$WORK/wt")")")
has "git: linked worktree is detected without stdin help" "$out" "(feature/x) ⎇wt"
out=$(line1 "$(render "$(payload '.cwd = $d' --arg d "$WORK/repo")")")
hasnt "git: main tree is not a worktree" "$out" "⎇wt"
has   "git: clean tree shows the branch only" "$out" "(main ⇡1)"
out=$(line1 "$(render "$(payload '.cwd = $d | .workspace.git_worktree = "x"' --arg d "$WORK/plain")")")
has "git: worktree from stdin" "$out" "⎇wt"
g checkout -q --detach
sha=$(git -C "$WORK/repo" rev-parse --short=7 HEAD)
out=$(line1 "$(render "$(payload '.cwd = $d' --arg d "$WORK/repo")")")
has "git: detached head shows the commit" "$out" "($sha)"

# ── Usage API: background fetch, digest, rows ───────────────────────
cat > "$WORK/bin/curl" <<EOF
#!/usr/bin/env bash
cat >/dev/null            # the config with the token arrives on stdin
echo run >> "$WORK/curl-calls"
cat "\${CESL_FAKE_USAGE:-$FIX/usage.json}"
EOF
chmod +x "$WORK/bin/curl"
OLDPATH=$PATH
export PATH="$WORK_POSIX/bin:$PATH"
export CLAUDE_CODE_OAUTH_TOKEN=test-token
export CESL_SHOW_SCOPED=1 CESL_SHOW_EXTRA=1
cdir=$(cache_dir)

out=$(render "$base")
hasnt "first render does not wait for the API" "$out" "fable"
i=0
while [ ! -f "$cdir/usage-digest" ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$(( i + 1 )); done
if [ -f "$cdir/usage-digest" ]; then ok; else ko "background fetch writes the digest" "no $cdir/usage-digest after 10s"; fi
i=0
while [ -f "$cdir/fetch.lck" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$(( i + 1 )); done
if [ -f "$cdir/fetch.lck" ]; then ko "background fetch releases the lock" "lock still present"; else ok; fi
is "no temp files left behind" "$(ls "$cdir" | grep -c '\.[0-9][0-9]*$')" "0"

out=$(render "$base")
has   "scoped row: inactive but used is shown" "$out" "fable   █████░░░░░  57% ⟳ nov 12"
has   "scoped row: active"                     "$out" "sonnet  █░░░░░░░░░  12% ⟳ nov 13"
hasnt "scoped row: inactive and unused is hidden" "$out" "ghost"
has   "extra row"                              "$out" 'extra   ██░░░░░░░░ $5.12/$20.00 ⟳ dec 1'
is "fresh digest: no second request" "$(wc -l < "$WORK/curl-calls" | tr -d ' ')" "1"

out=$(printf '%s' "$base" | CESL_SHOW_SCOPED=0 "$SH" "$SL")
hasnt "scoped off" "$out" "fable"
has   "scoped off keeps extra" "$out" "extra"
out=$(printf '%s' "$base" | CESL_SHOW_EXTRA=0 "$SH" "$SL")
hasnt "extra off" "$out" "extra "
has   "extra off keeps scoped" "$out" "fable"

# Stale digest: still rendered, and one refresh starts in the background
out=$(printf '%s' "$base" | CESL_NOW=$(( CESL_NOW + 3600 )) "$SH" "$SL")
has "stale digest is still rendered" "$out" "fable"
i=0
while [ "$(wc -l < "$WORK/curl-calls" | tr -d ' ')" -lt 2 ] && [ "$i" -lt 100 ]; do sleep 0.1; i=$(( i + 1 )); done
is "stale digest triggers one refresh" "$(wc -l < "$WORK/curl-calls" | tr -d ' ')" "2"
i=0
while [ -f "$cdir/fetch.lck" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$(( i + 1 )); done

# More than 24h old: not rendered
out=$(printf '%s' "$base" | CESL_NOW=$(( CESL_NOW + 200000 )) CLAUDE_CODE_OAUTH_TOKEN='' "$SH" "$SL")
hasnt "digest older than 24h is ignored" "$out" "fable"
i=0
while [ -f "$cdir/fetch.lck" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$(( i + 1 )); done

# An error body never reaches the cache, and the failure backs off
rm -rf "$cdir"
: > "$WORK/curl-calls"
out=$(printf '%s' "$base" | CESL_FAKE_USAGE="$FIX/usage-error.json" "$SH" "$SL" explain)
has "error body: fetch reported as failed" "$out" "fetch:        failed"
if [ -f "$cdir/usage-digest" ] || [ -f "$cdir/usage-cache.json" ]; then ko "error body is not cached" "cache files exist"; else ok; fi
out=$(explain "$base")
has "failed fetch backs off" "$out" "fetch:        skipped (a fetch failed"
is  "back-off: no second request" "$(wc -l < "$WORK/curl-calls" | tr -d ' ')" "1"

# explain fetches in the foreground and reports what it did
rm -rf "$cdir"
out=$(explain "$base")
has "explain: fetch in the foreground" "$out" "fetch:        refreshed"
has "explain: digest state"            "$out" "digest:       fresh"
has "explain: prompt cache"            "$out" "prompt cache: ttl=1h"
has "explain: turn rate source"        "$out" "at rate 0.05, source: auto"

# A lock held by a live fetch is respected; a dead one is taken over
rm -rf "$cdir"; mkdir -p "$cdir"; : > "$WORK/curl-calls"
printf '%s\n' "$CESL_NOW" > "$cdir/fetch.lck"
out=$(explain "$base")
has "live lock is respected" "$out" "skipped (another session is fetching)"
printf '%s\n' "$(( CESL_NOW - 120 ))" > "$cdir/fetch.lck"
out=$(explain "$base")
has "dead lock is taken over" "$out" "fetch:        refreshed"

# No usage rows wanted: no cache directory, no request
rm -rf "$cdir"; : > "$WORK/curl-calls"
out=$(printf '%s' "$base" | CESL_SHOW_SCOPED=0 CESL_SHOW_EXTRA=0 "$SH" "$SL")
if [ -d "$cdir" ]; then ko "offline mode creates no cache" "$cdir exists"; else ok; fi
is "offline mode makes no request" "$(wc -l < "$WORK/curl-calls" | tr -d ' ')" "0"

export PATH=$OLDPATH
unset CLAUDE_CODE_OAUTH_TOKEN
export CESL_SHOW_SCOPED=0 CESL_SHOW_EXTRA=0

# ── Configuration layering ──────────────────────────────────────────
printf 'CESL_SHOW_EFFORT=0\nCESL_CURRENCY_SYMBOL=EUR\n' > "$WORK/config.sh"
out=$(printf '%s' "$base" | CESL_CONFIG="$WORK/config.sh" "$SH" "$SL")
hasnt "config file is applied" "$out" "medium"
has   "config file: currency"  "$out" "EUR3.46"
out=$(printf '%s' "$base" | CESL_CONFIG="$WORK/config.sh" CESL_SHOW_EFFORT=1 CESL_CURRENCY_SYMBOL='£' "$SH" "$SL")
has "environment wins over the config file" "$out" "◑ medium"
has "environment wins: currency"            "$out" "£3.46"
out=$(printf '%s' "$base" | CESL_WARN=abc CESL_BAR_WIDTH=0 CESL_CTX_HIGH=x "$SH" "$SL")
has "bad numeric knobs fall back" "$out" "7-day   █████████░  94%"

# ── Process budget ──────────────────────────────────────────────────
# The render path must stay cheap (see the performance rule in statusline.sh).
# Every $(...) is a process, ~60 ms on Windows. The script keeps helpers on
# $_r; what is left is one jq, one git, and fallbacks that only run on bash 3.2
# or on unusual input. A new $(...) must be a decision, not an accident.
n=$(grep -v '^[[:space:]]*#' "$SL" | grep -c '\$([^(]')
is "process budget: command substitutions in statusline.sh" "$n" "$BUDGET"

echo
if [ "$fail" -eq 0 ]; then
    echo "OK — $pass checks passed"
else
    echo "$fail FAILED, $pass passed"
    exit 1
fi

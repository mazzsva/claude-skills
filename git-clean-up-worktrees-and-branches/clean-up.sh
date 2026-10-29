#!/bin/bash
# Copyright © 2026 Lorenzo Mazzarotto
set -u
export LC_ALL=C GIT_TERMINAL_PROMPT=0 GIT_OPTIONAL_LOCKS=0
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=10}"

APPLY=""
RAW_INCLUDE=""
STALE_DAYS=30
QUIET_MINUTES=${CLEAN_UP_QUIET_MINUTES:-30}
FETCH=1
REPOS=""
NL='
'
TAB='	'

usage() {
  echo "usage: clean-up.sh [--apply] [--no-fetch] [--include <worktree or branch>]... [<repository>...]"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) APPLY=1 ;;
    --no-fetch) FETCH="" ;;
    --include)
      [ $# -ge 2 ] || { usage >&2; exit 2; }
      RAW_INCLUDE="$RAW_INCLUDE$2$NL"; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) usage >&2; exit 2 ;;
    *) REPOS="$REPOS$1$NL" ;;
  esac
  shift
done
[ -n "$REPOS" ] || REPOS=".$NL"

TMP=$(mktemp -d "${TMPDIR:-/tmp/}git-clean-up.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT
FAILED=""
NOW=$(date +%s)
HERE=$(pwd -P)

count() {
  if [ "$1" -eq 1 ]; then echo "1 $2"; else echo "$1 $3"; fi
}

say() {
  printf '%s | %s | %s | %s\n' "$1" "$2" "$3" "$4"
}

real() {
  (cd "$1" 2>/dev/null && pwd -P)
}

norm() {
  printf '%s\n' "$1" | awk -F/ '{
    n = 0
    for (i = 1; i <= NF; i++) {
      if ($i == "" || $i == ".") continue
      if ($i == "..") { if (n > 0) n--; continue }
      s[++n] = $i
    }
    out = ""
    for (i = 1; i <= n; i++) out = out "/" s[i]
    print (out == "" ? "/" : out)
  }'
}

shq() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

in_list() {
  case "$NL$2" in *"$NL$1$NL"*) return 0 ;; esac
  return 1
}

inside() {
  case "$1/" in "$2"/*) return 0 ;; esac
  return 1
}

short() {
  case "$1" in
    refs/remotes/*) echo "${1#refs/remotes/}" ;;
    refs/heads/*) echo "${1#refs/heads/}" ;;
    *) echo "$1" ;;
  esac
}

protected() {
  case "$1" in "$MAINLINE_NAME"|main|master|trunk|develop) return 0 ;; esac
  return 1
}

with_timeout() {
  local secs=$1 pid st
  shift
  "$@" &
  pid=$!
  ( trap 'kill "$s" 2>/dev/null; exit 0' TERM; sleep "$secs" & s=$!; wait "$s"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  local w=$!
  wait "$pid"; st=$?
  kill "$w" 2>/dev/null; wait "$w" 2>/dev/null
  return $st
}

move_to_trash() {
  if [ -n "${CLEAN_UP_TRASH_DIR:-}" ]; then
    local name dest n=1
    name=$(basename "$1")
    dest="$CLEAN_UP_TRASH_DIR/$name"
    while [ -e "$dest" ] || [ -L "$dest" ]; do n=$((n + 1)); dest="$CLEAN_UP_TRASH_DIR/$name $n"; done
    mv "$1" "$dest"
  else
    /usr/bin/trash -s "$1" >/dev/null 2>&1
  fi
}

find_mainlines() {
  local r sym name="" ref seen="" sha
  MAINLINE_NAME=""
  MAINLINE_REMOTE=""
  MAINLINES=""
  for r in origin $(git remote); do
    sym=$(git symbolic-ref -q "refs/remotes/$r/HEAD" 2>/dev/null) || continue
    name=${sym#refs/remotes/$r/}
    MAINLINE_REMOTE=$r
    break
  done
  if [ -z "$name" ]; then
    for ref in main master trunk develop; do
      if git show-ref -q --verify "refs/remotes/origin/$ref"; then name=$ref; MAINLINE_REMOTE=origin; break; fi
      if git show-ref -q --verify "refs/heads/$ref"; then name=$ref; break; fi
    done
  fi
  [ -n "$name" ] || return 1
  MAINLINE_NAME=$name; export MAINLINE_NAME
  for ref in ${MAINLINE_REMOTE:+refs/remotes/$MAINLINE_REMOTE/$name} "refs/heads/$name"; do
    sha=$(git rev-parse -q --verify "$ref^{commit}" 2>/dev/null) || continue
    in_list "$sha" "$seen" && continue
    seen="$seen$sha$NL"
    MAINLINES="$MAINLINES$ref$NL"
  done
  [ -n "$MAINLINES" ]
}

find_live_refs() {
  local r out
  LIVE=""
  LIVE_KNOWN=""
  LIVE_PARTIAL=""
  [ -n "$FETCH" ] || return 0
  for r in $(git remote); do
    if out=$(with_timeout 20 git ls-remote --heads "$r" 2>/dev/null); then
      LIVE="$LIVE$(printf '%s\n' "$out" | R=$r awk -F'\t' 'NF == 2 { sub(/^refs\/heads\//, "", $2); print "refs/remotes/" ENVIRON["R"] "/" $2 }')$NL"
    else
      LIVE="$LIVE$(git for-each-ref --format='%(refname)' "refs/remotes/$r")$NL"
      LIVE_PARTIAL=1
    fi
  done
  printf '%s\n' "$LIVE" >"$TMP/live.wanted"
  git for-each-ref --format='%(refname)' refs/remotes >"$TMP/live.have"
  LIVE=$(awk 'NR == FNR { want[$0] = 1; next } want[$0]' "$TMP/live.wanted" "$TMP/live.have")
  LIVE_KNOWN=1
  [ -z "$LIVE_PARTIAL" ]
}

load_pull_requests() {
  MERGED_PRS=""
  command -v gh >/dev/null 2>&1 || return 0
  git remote get-url "${MAINLINE_REMOTE:-origin}" 2>/dev/null | grep -q 'github\.com' || return 0
  MERGED_PRS=$(cd "$TOP" 2>/dev/null && MAINLINE_NAME=$MAINLINE_NAME with_timeout 30 gh pr list --state merged --base "$MAINLINE_NAME" --limit 1000 --json number,headRefOid,baseRefName --jq '.[] | select(.baseRefName == env.MAINLINE_NAME) | "\(.headRefOid) \(.number)"' 2>/dev/null) || MERGED_PRS=""
}

lost_blobs() {
  if [ ! -f "$TMP/held" ]; then
    exclusions | sed 's/^\^//' >"$TMP/held.refs"
    git rev-list --objects --no-object-names --stdin $( [ -n "$LIVE_KNOWN" ] || echo --remotes ) <"$TMP/held.refs" >"$TMP/held.new" 2>/dev/null || { echo 1; return; }
    sort -u "$TMP/held.new" >"$TMP/held"
  fi
  exclusions >"$TMP/revs"
  git rev-list --objects --no-object-names "$1" --stdin $(remotes_not) <"$TMP/revs" >"$TMP/candidates" 2>/dev/null || { echo 1; return; }
  git cat-file --batch-check='%(objectname) %(objecttype)' <"$TMP/candidates" 2>/dev/null >"$TMP/types" || { echo 1; return; }
  awk '$2 != "commit" && $2 != "tree" { print $1 }' "$TMP/types" | sort -u | comm -23 - "$TMP/held" | grep -c .
}

merged_how() {
  local c=$1 m base pid out t pr x since unpushed f lost=0 found=""
  local paths
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    if git merge-base --is-ancestor "$c" "$m" 2>/dev/null; then
      echo "merged into $(short "$m")"
      return 0
    fi
  done <<EOF
$MAINLINES
EOF
  pr=$(printf '%s\n' "$MERGED_PRS" | awk -v c="$c" '$1 == c { print $2; exit }')
  if [ -n "$pr" ]; then
    echo "merged in pull request #$pr"
    return 0
  fi
  unpushed=$(unpushed_count "$c")
  while IFS= read -r m; do
    [ -n "$m" ] || continue
    base=$(git merge-base "$m" "$c" 2>/dev/null) || continue
    [ "$(git rev-parse "$c^{tree}")" = "$(git rev-parse "$base^{tree}")" ] && continue
    if out=$(git merge-tree --write-tree --no-messages "$m" "$c" 2>/dev/null); then
      t=${out%%$NL*}
      if [ -n "$t" ] && [ "$t" = "$(git rev-parse "$m^{tree}")" ]; then
        found="its changes are already in $(short "$m")"
        break
      fi
    fi
    pid=$(git diff-tree -p --binary --no-ext-diff --no-textconv "$base" "$c" | git patch-id --verbatim | cut -d' ' -f1)
    [ -n "$pid" ] || continue
    paths=()
    while IFS= read -r -d '' f; do paths[${#paths[@]}]=":(literal)$f"; done < <(git diff --name-only -z --no-renames "$base" "$c")
    [ ${#paths[@]} -gt 0 ] && [ ${#paths[@]} -le 500 ] || paths=(.)
    since=$(date -r $(( $(git log -1 --format=%ct "$c") - 7 * 86400 )) '+%Y-%m-%dT%H:%M:%S%z')
    for x in $(git log -p --binary --no-merges --no-ext-diff --no-textconv --since="$since" "$base..$m" -- "${paths[@]}" | git patch-id --verbatim | awk -v p="$pid" '$1 == p { print $2 }'); do
      out=$(git merge-tree --write-tree --no-messages --merge-base="$base" "$x" "$c" 2>/dev/null) || continue
      if [ "${out%%$NL*}" = "$(git rev-parse "$x^{tree}")" ]; then
        found="squash-merged into $(short "$m")"
        break
      fi
    done
    [ -n "$found" ] && break
  done <<EOF
$MAINLINES
EOF
  [ -n "$found" ] || return 1
  [ "$unpushed" -gt 0 ] && lost=$(lost_blobs "$c")
  if [ "$lost" -gt 0 ]; then
    echo "$found, but $(count "$unpushed" "commit that is not pushed holds" "commits that are not pushed hold") $(count "$lost" "file version" "file versions") that nothing else holds"
    return 2
  fi
  echo "$found"
  return 0
}

exclusions() {
  if [ -n "$LIVE_KNOWN" ]; then
    printf '%s\n' "$LIVE" "$MAINLINES" | sed -n 's/^refs\//^refs\//p'
  else
    printf '%s\n' "$MAINLINES" | sed -n 's/^refs\//^refs\//p'
  fi
}

remotes_not() {
  [ -n "$LIVE_KNOWN" ] || echo "--not --remotes"
}

unpushed_count() {
  exclusions >"$TMP/revs"
  git rev-list --count "$1" --stdin $(remotes_not) <"$TMP/revs" 2>/dev/null || echo 1
}

age_days() {
  local t
  t=$(git log -1 --format=%ct "$1" 2>/dev/null) || t=$NOW
  echo $(( (NOW - t) / 86400 ))
}

not_merged() {
  local c=$1 label=$2 n days
  n=$(unpushed_count "$c")
  if [ "$n" -gt 0 ]; then
    FATE=keep
    WHY="$(count "$n" commit commits) not pushed"
    return
  fi
  if in_list "$label" "$INCLUDE" && [ -n "${LIVE_PARTIAL:-}" ]; then
    FATE=keep
    WHY="pushed, not merged; a remote did not answer, so it is not sure that the server still holds it"
    return
  fi
  if in_list "$label" "$INCLUDE"; then
    FATE=trash
    WHY="pushed, not merged; you asked to include it"
    return
  fi
  days=$(age_days "$c")
  if [ "$days" -ge "$STALE_DAYS" ]; then
    FATE=ask
    WHY="pushed, not merged; no commit for $days days"
  else
    FATE=keep
    WHY="pushed, not merged; last commit $days days ago"
  fi
}

lock_is_live() {
  local pid
  pid=$(printf '%s\n' "$1" | sed -n 's/^claude agent .*(pid \([0-9][0-9]*\).*/\1/p')
  [ -n "$pid" ] || return 0
  kill -0 "$pid" 2>/dev/null && return 0
  ps -p "$pid" >/dev/null 2>&1
}

count_changes() {
  local wt=$1 skip_list=$2 n=0 skip="" f
  git -C "$wt" status --porcelain=v1 -z --untracked-files=all --ignore-submodules=none >"$TMP/status" 2>/dev/null || return 1
  while IFS= read -r -d '' f; do
    if [ -n "$skip" ]; then skip=""; continue; fi
    case "${f:0:2}" in R?|C?|?R|?C) skip=1 ;; esac
    if [ "${f:0:3}" = "?? " ] && { in_list "${f:3}" "$skip_list" || [ -L "$wt/${f:3}" ]; }; then continue; fi
    n=$((n + 1))
  done <"$TMP/status"
  echo "$n"
}

hidden_count() {
  local wt=$1 sparse
  sparse=$(git -C "$wt" config --bool core.sparseCheckout 2>/dev/null || echo false)
  if [ "$sparse" = true ]; then
    git -C "$wt" ls-files -v | grep -c '^[a-z]'
  else
    git -C "$wt" ls-files -v | grep -c -e '^[a-z]' -e '^S '
  fi
}

list_ignored() {
  git -C "$1" status --porcelain=v1 -z --untracked-files=normal --ignored=matching >"$TMP/ignored" 2>/dev/null
}

ignored_note() {
  local f n=0 names=""
  while IFS= read -r -d '' f; do
    [ "${f:0:3}" = "!! " ] || continue
    [ -L "$1/${f:3}" ] && continue
    n=$((n + 1))
    [ $n -le 3 ] && names="$names, ${f:3}"
  done <"$TMP/ignored"
  [ $n -eq 0 ] && return 0
  [ $n -gt 3 ] && names="$names, and $((n - 3)) more"
  printf '; its ignored files go with it: %s' "${names#, }"
}

child_worktree() {
  local d=$1 wt=$2 j=0 w
  while [ $j -lt $WT_N ]; do
    w=${WT_REAL[$j]}
    if [ "$w" != "$wt" ] && inside "$w" "$wt" && { [ "$d" = "$w" ] || inside "$d" "$w"; }; then return 0; fi
    j=$((j + 1))
  done
  return 1
}

module_git() {
  git --git-dir="$1" --work-tree="$1" "${@:2}"
}

nested_work() {
  local wt=$1 admin=$2 f d
  : >"$TMP/found"
  if [ -n "$wt" ]; then
    find "$wt" -mindepth 1 \( -name .git -prune -print \) -o \( \( -name HEAD -o -name packed-refs \) \( -type f -o -type l \) -print \) >"$TMP/found" 2>/dev/null ||
      { echo "a folder inside it that cannot be read"; return 0; }
  fi
  if [ -d "$admin/modules" ]; then
    find "$admin/modules" \( -name HEAD -o -name packed-refs \) \( -type f -o -type l \) >>"$TMP/found" 2>/dev/null || { echo "a submodule that cannot be read"; return 0; }
  fi
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    d=$(dirname "$f")
    [ -n "$wt" ] && [ "$d" = "$wt" ] && continue
    case "$f" in
      */.git)
        child_worktree "$(real "$d")" "$wt" && continue
        if [ "$(real "$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)")" != "$(real "$d")" ] ||
           [ -n "$(git -C "$d" status --porcelain --untracked-files=all 2>&1)" ] ||
           [ -n "$(git -C "$d" rev-list -n 1 --all --not --remotes 2>&1)" ]; then
          echo "the repository ${d#"$wt/"} inside it"; return 0
        fi ;;
      *)
        [ -n "$wt" ] && child_worktree "$(real "$d")" "$wt" && continue
        if ! module_git "$d" rev-parse --git-dir >/dev/null 2>&1; then
          [ -d "$d/objects" ] && [ -d "$d/refs" ] || continue
        fi
        [ -n "$wt" ] && inside "$d" "$wt" && git -C "$wt" ls-files --error-unmatch -- ":(literal)${f#"$wt/"}" >/dev/null 2>&1 && continue
        if [ -n "$(module_git "$d" rev-list -n 1 --all --not --remotes 2>&1)" ]; then
          case "$d" in
            "$admin"/modules/*) echo "the submodule ${d#"$admin/modules/"}" ;;
            *) echo "the repository ${d#"$wt/"} inside it" ;;
          esac
          return 0
        fi ;;
    esac
  done <"$TMP/found"
  if [ -n "$(git --git-dir="$admin" for-each-ref --format='%(objectname)' refs/worktree refs/bisect 2>/dev/null)" ] &&
     [ -n "$(git rev-list -n 1 $(git --git-dir="$admin" for-each-ref --format='%(objectname)' refs/worktree refs/bisect) --not --branches --tags --remotes 2>&1)" ]; then
    echo "a per-worktree ref"; return 0
  fi
  return 1
}

load_sessions() {
  local f pid cwd mine=" " p=$$ dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions"
  : >"$TMP/sessions"
  command -v plutil >/dev/null 2>&1 || return 0
  while [ -n "$p" ] && [ "$p" -gt 1 ]; do
    mine="$mine$p "
    p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ')
  done
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    pid=$(plutil -extract pid raw -o - "$f" 2>/dev/null) || continue
    cwd=$(plutil -extract cwd raw -o - "$f" 2>/dev/null) || continue
    case "$pid" in ''|*[!0-9]*) continue ;; esac
    kill -0 "$pid" 2>/dev/null || ps -p "$pid" >/dev/null 2>&1 || continue
    cwd=$(real "$cwd")
    [ -n "$cwd" ] || continue
    case "$mine" in *" $pid "*) printf 'self\t%s\t%s\n' "$pid" "$cwd" ;; *) printf 'other\t%s\t%s\n' "$pid" "$cwd" ;; esac >>"$TMP/sessions"
  done
}

claude_session() {
  local who pid cwd
  while IFS="$TAB" read -r who pid cwd; do
    if [ "$cwd" = "$1" ] || inside "$cwd" "$1"; then echo "a Claude Code session ($pid)"; return 0; fi
  done <"$TMP/sessions"
  return 1
}

parent_session() {
  local who pid cwd
  while IFS="$TAB" read -r who pid cwd; do
    [ "$who" = other ] || continue
    if inside "$1" "$cwd"; then echo "$pid $cwd"; return 0; fi
  done <"$TMP/sessions"
  return 1
}

busy_process() {
  WT=$1 awk '
    BEGIN { wt = ENVIRON["WT"]; gsub(/[^ -~]|\\/, "?", wt) }
    /^p/ { pid = substr($0, 2) }
    /^c/ { cmd = substr($0, 2) }
    /^n/ {
      if (cmd ~ /^(mds|mdworker|fseventsd)/) next
      p = substr($0, 2)
      gsub(/\\x[0-9a-f][0-9a-f]|\\./, "?", p)
      gsub(/[^ -~]/, "?", p)
      if (p == wt || index(p, wt "/") == 1) { print cmd " (" pid ")"; exit }
    }
  ' "$TMP/files"
}

open_files() {
  lsof +c 0 -F pcn 2>/dev/null >"$TMP/files"
}

admin_dir_for() {
  local d g want rp
  want=$(norm "$1")
  rp=$(real "$1")
  for d in "$COMMON"/worktrees/*/; do
    d=${d%/}
    [ -f "$d/gitdir" ] || continue
    g=$(cat "$d/gitdir")
    case "$g" in /*) ;; *) g="$d/$g" ;; esac
    g=$(norm "$g")
    g=${g%/.git}
    if [ "$g" = "$want" ] || { [ -n "$rp" ] && [ "$(real "$g")" = "$rp" ]; }; then echo "$d"; return 0; fi
  done
  return 1
}

held_branch() {
  local admin=$1 f b
  for f in rebase-merge/head-name rebase-apply/head-name BISECT_START; do
    [ -f "$admin/$f" ] || continue
    b=$(head -1 "$admin/$f")
    echo "${b#refs/heads/}"
  done
}

judge_missing() {
  local path=$1 admin=$2 head=$3 branch=$4 d nested
  case "$path" in
    /Volumes/*)
      if [ ! -d "$(printf '%s\n' "$path" | cut -d/ -f1-3)" ]; then FATE=keep; WHY="its disk is not connected"; return; fi ;;
  esac
  d=$(dirname "$path")
  while [ ! -e "$d" ] && [ "$d" != / ]; do d=$(dirname "$d"); done
  if [ ! -x "$d" ] || [ ! -r "$d" ]; then FATE=keep; WHY="its folder cannot be read"; return; fi
  if [ -z "$admin" ]; then FATE=keep; WHY="its folder is gone and its git record was not found"; return; fi
  if nested=$(nested_work "" "$admin"); then FATE=keep; WHY="its folder is gone, but $nested holds work that is not pushed"; return; fi
  if [ -z "$branch" ] && [ -n "$head" ] && git rev-parse -q --verify "$head^{commit}" >/dev/null &&
     [ -n "$(git rev-list -n 1 "$head" --not --branches --tags --remotes 2>&1)" ]; then
    FATE=keep; WHY="its folder is gone, but its git record holds commits on no branch"; return
  fi
  FATE=prune; WHY="its folder is gone; its git record goes to the Trash"
}

judge_worktree() {
  local i=$1 path=${WT_PATH[$1]} rp=${WT_REAL[$1]} branch=${WT_BRANCH[$1]} head=${WT_HEAD[$1]}
  local admin=${WT_ADMIN[$1]} gd top j n f children="" how label proc nested

  if [ -n "$branch" ] && protected "$branch"; then FATE=keep; WHY="it holds the $branch branch"; return; fi
  if [ -n "${WT_LOCKED[$i]}" ] && lock_is_live "${WT_LOCK[$i]}"; then
    FATE=keep; WHY="locked: ${WT_LOCK[$i]:-no reason given}"; return
  fi
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then judge_missing "$path" "$admin" "$head" "$branch"; return; fi
  if [ -L "$path" ]; then FATE=keep; WHY="its path is a symbolic link"; return; fi
  if [ ! -d "$path" ]; then FATE=keep; WHY="its path is not a folder"; return; fi
  if [ -z "$admin" ]; then FATE=keep; WHY="its git record was not found; git worktree repair fixes it"; return; fi
  gd=$(real "$(git -C "$path" rev-parse --absolute-git-dir 2>/dev/null)")
  top=$(real "$(git -C "$path" rev-parse --show-toplevel 2>/dev/null)")
  if [ -z "$gd" ] || [ "$gd" != "$(real "$admin")" ] || [ "$top" != "$rp" ]; then
    FATE=keep; WHY="its .git link is broken; git worktree repair fixes it"; return
  fi
  if [ "$HERE" = "$rp" ] || inside "$HERE" "$rp"; then FATE=keep; WHY="this session works in it"; return; fi
  if [ "$REPO_REAL" = "$rp" ] || inside "$REPO_REAL" "$rp"; then FATE=keep; WHY="it is the repository you named"; return; fi
  proc=$(busy_process "$rp")
  if [ -n "$proc" ]; then FATE=keep; WHY="$proc works in it"; return; fi
  if proc=$(claude_session "$rp"); then FATE=keep; WHY="$proc works in it"; return; fi
  if [ "$QUIET_MINUTES" -gt 0 ] && { [ -n "$(find "$rp" "$admin" -mmin "-$QUIET_MINUTES" -not -path "$admin/*.lock" -print -quit 2>/dev/null)" ]; }; then
    FATE=keep; WHY="a file in it changed in the last $QUIET_MINUTES minutes"; return
  fi
  j=0
  while [ $j -lt $WT_N ]; do
    if [ $j -ne $i ] && inside "${WT_REAL[$j]}" "$rp"; then
      case "${WT_FATE[$j]}" in
        trash|prune) children="$children${WT_REAL[$j]#"$rp/"}/$NL" ;;
        *) FATE=keep; WHY="it holds the worktree ${WT_PATH[$j]}, which stays"; return ;;
      esac
    fi
    j=$((j + 1))
  done
  for f in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG; do
    if [ -e "$admin/$f" ]; then FATE=keep; WHY="a rebase, merge, cherry-pick, revert, or bisect is in progress"; return; fi
  done
  n=$(count_changes "$path" "$children") || { FATE=keep; WHY="git status failed"; return; }
  if [ "$n" -gt 0 ]; then FATE=keep; WHY="$(count "$n" "uncommitted change" "uncommitted changes")"; return; fi
  n=$(hidden_count "$path")
  if [ "$n" -gt 0 ]; then FATE=keep; WHY="$(count "$n" "file is" "files are") hidden from git status"; return; fi
  list_ignored "$path" || { FATE=keep; WHY="git status failed"; return; }
  if nested=$(nested_work "$path" "$admin"); then
    FATE=keep; WHY="$nested holds work that is not pushed"; return
  fi
  if [ -z "$head" ] || ! git rev-parse -q --verify "$head^{commit}" >/dev/null; then
    if [ -z "$(ignored_note "$path")" ]; then FATE=trash; WHY="holds no commits and no files"; else FATE=keep; WHY="holds no commits, but holds ignored files"; fi
    return
  fi
  how=$(merged_how "$head")
  case $? in
    0)
      FATE=trash; WHY="$how$(ignored_note "$path")"
      if proc=$(parent_session "$rp") && [ -n "$(find "$rp" "$admin" -mmin -1440 -print -quit 2>/dev/null)" ]; then
        if in_list "$path" "$INCLUDE" || in_list "$rp" "$INCLUDE" || { [ -n "$branch" ] && in_list "$branch" "$INCLUDE"; }; then
          WHY="$WHY; you asked to include it"
        else
          FATE=ask; WHY="$how, but the Claude Code session ${proc%% *}, started in ${proc#* }, may work in it; a file in it changed today"
        fi
      fi
      return ;;
  esac
  label=$path
  in_list "$path" "$INCLUDE" || in_list "$rp" "$INCLUDE" || { [ -n "$branch" ] && label=$branch; }
  if [ -n "$how" ]; then
    if in_list "$label" "$INCLUDE"; then FATE=trash; WHY="$how; you asked to include it"; else FATE=ask; WHY=$how; fi
  else
    not_merged "$head" "$label"
  fi
  [ "$FATE" = trash ] && WHY="$WHY$(ignored_note "$path")"
}

remove_worktree() {
  local i=$1 path=${WT_PATH[$1]} admin=${WT_ADMIN[$1]} proc now
  if [ "${WT_FATE[$i]}" = trash ]; then
    open_files
    proc=$(busy_process "${WT_REAL[$i]}")
    if [ -n "$proc" ]; then WT_FATE[$i]=keep; WT_WHY[$i]="$proc works in it"; return; fi
    now=$(git -C "$path" rev-parse -q --verify HEAD 2>/dev/null)
    if [ "$now" != "${WT_HEAD[$i]}" ] || [ "$(count_changes "$path" "")" != 0 ]; then
      WT_FATE[$i]=keep; WT_WHY[$i]="it changed while this ran"; return
    fi
    if ! move_to_trash "$path"; then
      WT_FATE[$i]=fail; WT_WHY[$i]="the move to the Trash failed; nothing changed"; return
    fi
  fi
  if [ -n "$admin" ] && [ -d "$admin" ] && ! move_to_trash "$admin"; then
    WT_FATE[$i]=fail; WT_WHY[$i]="the folder is in the Trash, but its git record stays; git worktree prune removes it"
  fi
}

clean_repo() {
  local repo=$1 i order branch sha how up label admin line sym kept_branches="" verb
  local trashed=0 deleted=0 kept=0 asked=0 failed=0

  if ! COMMON=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir 2>/dev/null); then
    say FAILED repository "$repo" "not a git repository"; FAILED=1; return
  fi
  COMMON=$(real "$COMMON")
  REPO_REAL=$(real "$repo")
  rm -f "$TMP/held"
  cd "$COMMON" || { say FAILED repository "$repo" "cannot open $COMMON"; FAILED=1; return; }

  if [ -n "$FETCH" ] && [ -n "$(git remote)" ]; then
    with_timeout 60 git fetch --quiet --all --no-prune --no-write-fetch-head >/dev/null 2>&1 ||
      say NOTE repository "$repo" "the fetch failed; the results use the last fetch"
  fi
  if ! find_live_refs; then
    say NOTE repository "$repo" "a remote did not answer; for that remote, the results use the last fetch"
  fi
  if [ -n "$(git remote)" ] && [ -z "$(git for-each-ref --count=1 refs/remotes)" ]; then
    say NOTE repository "$repo" "it has no remote-tracking branches, so work that is pushed counts as not pushed"
  fi
  if ! find_mainlines; then
    say FAILED repository "$repo" "no main branch found; nothing changed"; FAILED=1; return
  fi

  WT_N=0
  local key
  while IFS= read -r -d '' key; do
    case "$key" in
      "worktree "*)
        WT_PATH[$WT_N]=${key#worktree }; WT_HEAD[$WT_N]=""; WT_BRANCH[$WT_N]=""
        WT_LOCKED[$WT_N]=""; WT_LOCK[$WT_N]=""; WT_N=$((WT_N + 1)) ;;
      "HEAD "*) WT_HEAD[$((WT_N - 1))]=${key#HEAD } ;;
      "branch "*) WT_BRANCH[$((WT_N - 1))]=${key#branch refs/heads/} ;;
      locked) WT_LOCKED[$((WT_N - 1))]=1 ;;
      "locked "*) WT_LOCKED[$((WT_N - 1))]=1; WT_LOCK[$((WT_N - 1))]=$(printf '%s' "${key#locked }" | tr '\n\t' '  ') ;;
    esac
  done < <(git worktree list --porcelain -z 2>/dev/null)
  if [ "$WT_N" -eq 0 ]; then
    say FAILED repository "$repo" "git worktree list failed; nothing changed"; FAILED=1; return
  fi
  TOP=${WT_PATH[0]}
  load_pull_requests

  if [ -n "$APPLY" ]; then verb=apply; else verb="dry run"; fi
  say REPOSITORY repository "$TOP" "$verb; mainline $(printf '%s' "$MAINLINES" | sed 's#^refs/remotes/##; s#^refs/heads/##' | paste -sd ' ' -)"

  open_files
  load_sessions

  i=0
  while [ $i -lt $WT_N ]; do
    WT_REAL[$i]=""
    [ -e "${WT_PATH[$i]}" ] && WT_REAL[$i]=$(real "${WT_PATH[$i]}")
    [ -n "${WT_REAL[$i]}" ] || WT_REAL[$i]=${WT_PATH[$i]}
    WT_ADMIN[$i]=""
    [ $i -gt 0 ] && WT_ADMIN[$i]=$(admin_dir_for "${WT_PATH[$i]}")
    [ "${WT_HEAD[$i]}" = 0000000000000000000000000000000000000000 ] && WT_HEAD[$i]=""
    WT_FATE[$i]=""; WT_WHY[$i]=""
    i=$((i + 1))
  done
  WT_FATE[0]=main

  order=$(i=1; while [ $i -lt $WT_N ]; do printf '%d %d\n' "${#WT_REAL[$i]}" "$i"; i=$((i + 1)); done | sort -rn | cut -d' ' -f2)
  for i in $order; do
    FATE=""; WHY=""
    judge_worktree "$i"
    WT_FATE[$i]=$FATE; WT_WHY[$i]=$WHY
    if [ "$FATE" = trash ] && [ -n "${WT_BRANCH[$i]}" ] && { in_list "${WT_PATH[$i]}" "$INCLUDE" || in_list "${WT_REAL[$i]}" "$INCLUDE"; }; then
      INCLUDE="$INCLUDE${WT_BRANCH[$i]}$NL"
    fi
    if [ -n "$APPLY" ] && { [ "$FATE" = trash ] || [ "$FATE" = prune ]; }; then
      remove_worktree "$i"
    fi
    label=${WT_PATH[$i]}
    [ -n "${WT_BRANCH[$i]}" ] && label="$label (${WT_BRANCH[$i]})"
    case "${WT_FATE[$i]}" in
      trash|prune) if [ -n "$APPLY" ]; then verb=TRASHED; else verb=TRASH; fi
        say $verb worktree "$label" "${WT_WHY[$i]}"; trashed=$((trashed + 1)) ;;
      ask) say ASK worktree "$label" "${WT_WHY[$i]}"; asked=$((asked + 1)) ;;
      fail) say FAILED worktree "$label" "${WT_WHY[$i]}"; failed=$((failed + 1)); FAILED=1 ;;
      *) say KEEP worktree "$label" "${WT_WHY[$i]}"; kept=$((kept + 1)) ;;
    esac
  done

  i=0
  while [ $i -lt $WT_N ]; do
    case "${WT_FATE[$i]}" in
      trash|prune) ;;
      *)
        [ -n "${WT_BRANCH[$i]}" ] && kept_branches="$kept_branches${WT_BRANCH[$i]}$NL"
        if [ $i -eq 0 ]; then admin=$COMMON; else admin=${WT_ADMIN[$i]}; fi
        [ -n "$admin" ] && kept_branches="$kept_branches$(held_branch "$admin")$NL" ;;
    esac
    i=$((i + 1))
  done

  git for-each-ref --format="%(objectname):%(symref):%(upstream:track):%(refname)" refs/heads >"$TMP/branches"
  while IFS=: read -r sha sym up line; do
    branch=${line#refs/heads/}
    [ -z "$sym" ] || continue
    protected "$branch" && continue
    in_list "$branch" "$kept_branches" && continue
    how=$(merged_how "$sha")
    case $? in
      0) FATE=delete; WHY=$how ;;
      2) if in_list "$branch" "$INCLUDE"; then FATE=delete; WHY="$how; you asked to include it"; else FATE=ask; WHY=$how; fi ;;
      *)
      not_merged "$sha" "$branch"
      [ "$FATE" = trash ] && FATE=delete
      case "$up" in *gone*) WHY="$WHY; its remote branch is gone" ;; esac ;;
    esac
    if [ "$FATE" = delete ] && [ -n "$APPLY" ]; then
      if git update-ref --no-deref -d "refs/heads/$branch" "$sha" 2>/dev/null; then
        git config --remove-section "branch.$branch" >/dev/null 2>&1
      else
        FATE=fail; WHY="the delete failed; the branch stays"
      fi
    fi
    case "$FATE" in
      delete) if [ -n "$APPLY" ]; then verb=DELETED; else verb=DELETE; fi
        say $verb branch "$branch" "$WHY; restore with: git update-ref $(shq "refs/heads/$branch") $sha"; deleted=$((deleted + 1)) ;;
      ask) say ASK branch "$branch" "$WHY"; asked=$((asked + 1)) ;;
      fail) say FAILED branch "$branch" "$WHY"; failed=$((failed + 1)); FAILED=1 ;;
      *) say KEEP branch "$branch" "$WHY"; kept=$((kept + 1)) ;;
    esac
  done <"$TMP/branches"

  say DONE repository "$TOP" "$(count "$trashed" worktree worktrees) to the Trash, $(count "$deleted" branch branches) deleted, $kept kept, $asked to ask, $failed failed"
}

INCLUDE=""
while IFS= read -r item; do
  [ -n "$item" ] || continue
  trimmed=$item
  while [ "${trimmed%/}" != "$trimmed" ] && [ "$trimmed" != / ]; do trimmed=${trimmed%/}; done
  INCLUDE="$INCLUDE$item$NL$trimmed$NL"
  [ -d "$item" ] && INCLUDE="$INCLUDE$(real "$item")$NL"
done <<EOF
$RAW_INCLUDE
EOF

while IFS= read -r repo; do
  [ -n "$repo" ] || continue
  ( cd "$HERE" && clean_repo "$repo"; [ -z "$FAILED" ] ) || FAILED=1
done <<EOF
$REPOS
EOF

[ -z "$FAILED" ]

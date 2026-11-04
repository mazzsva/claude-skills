#!/bin/bash
# Copyright © 2026 Lorenzo Mazzarotto
set -uf
unset GIT_DIFF_OPTS GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS
export LC_ALL=C GIT_LITERAL_PATHSPECS=1 GIT_OPTIONAL_LOCKS=0

usage() {
  echo "usage: stage-lines.sh <file> [<line or range>...]"
}

fail() {
  printf 'stage-lines: %s\n' "$1" >&2
  exit 1
}

[ $# -ge 1 ] || { usage >&2; exit 2; }
case "$1" in -h|--help) usage; exit 0 ;; esac
path=$1
shift

[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = true ] || fail "not inside a git working tree"
[ -L "$path" ] && fail "$path is a symbolic link, stage it whole with git add"
[ -d "$path" ] && fail "$path is a folder, give one file"
[ -e "$path" ] || fail "$path does not exist, stage a deletion whole with git add"
[ -f "$path" ] || fail "$path is not a regular file"
case "$path" in *$'\n'*) fail "$path has a line break in its name, stage it whole with git add" ;; esac

full=$(git ls-files -z --deduplicate --full-name -c -o --exclude-standard -- "$path" | tr '\0' '\n')
[ -n "$full" ] || fail "$path is not a tracked or untracked file here: it is outside the repository, ignored, or behind a link"
[ "$(printf '%s\n' "$full" | wc -l)" -eq 1 ] || fail "$path names more than one file"
top=$(git rev-parse --show-toplevel) || exit 1
cd "$top" || exit 1

[ -z "$(git ls-files -u -- "$full")" ] || fail "$full has a merge conflict"
attr=$(git check-attr filter -- "$full")
case "${attr##*: }" in
  unspecified|unset) ;;
  *) fail "$full goes through the filter ${attr##*: }, stage it whole with git add" ;;
esac

TMP=$(mktemp -d "${TMPDIR:-/tmp}/stage-lines.XXXXXX") || exit 1
trap 'rm -rf "$TMP"' EXIT

cp -p "$(git rev-parse --git-path index)" "$TMP/index" 2>/dev/null
GIT_INDEX_FILE=$TMP/index git -c core.hooksPath=/dev/null -c core.splitIndex=false add -- "$full" || fail "cannot read $full"
new=$(GIT_INDEX_FILE=$TMP/index git rev-parse -q --verify ":0:$full") || fail "cannot read $full"
entry=$(git ls-files -s -- "$full")
old=$(git rev-parse -q --verify ":0:$full") || old=$(git hash-object -w --stdin </dev/null)
mode=${entry:-$(GIT_INDEX_FILE=$TMP/index git ls-files -s -- "$full")}
mode=${mode%% *}
case "$mode" in
  100644|100755) ;;
  *) fail "$full is not a regular file in the index, stage it whole with git add" ;;
esac
[ "$old" != "$new" ] || fail "$full holds no content change that is not staged, stage a mode change or an empty file whole with git add"

git cat-file blob "$old" >"$TMP/old" || fail "cannot read the staged version of $full"
git diff --no-color --no-ext-diff --no-textconv -U0 --inter-hunk-context=0 "$old" "$new" \
  >"$TMP/diff" || fail "cannot compare $full"
grep -q '^@@ ' "$TMP/diff" || fail "$full is binary, stage it whole with git add"
for f in old diff; do
  tr -d '\000' <"$TMP/$f" | cmp -s - "$TMP/$f" || fail "$full is binary, stage it whole with git add"
done

total=$(awk '/^@@ /{h=1; next} h && /^[-+]/{n++} END{print n+0}' "$TMP/diff")

if [ $# -eq 0 ]; then
  awk '
    /^@@ / { h = 1; print; next }
    !h { next }
    /^[-+]/ { n++; printf "%5d %s\n", n, $0; next }
    { printf "      %s\n", $0 }
  ' "$TMP/diff"
  exit 0
fi

want=""
for arg in "$@"; do
  for part in ${arg//,/ }; do
    case "$part" in
      *[!0-9-]*|-*|*-|*-*-*|*[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*) fail "$part is not a line or a range, such as 4 or 4-9" ;;
      *-*) lo=${part%-*}; hi=${part#*-} ;;
      *) lo=$part; hi=$part ;;
    esac
    lo=$((10#$lo)); hi=$((10#$hi))
    [ "$lo" -le "$hi" ] || fail "$part is backwards, give the lower number first, such as $hi-$lo"
    [ "$lo" -ge 1 ] && [ "$hi" -le "$total" ] ||
      fail "$part is outside 1-$total, list the lines again with: stage-lines.sh $path"
    want="$want $lo-$hi"
  done
done
[ -n "$want" ] || fail "give a line or a range, such as 4 or 4-9"

old_eol=1
if [ -s "$TMP/old" ] && [ -n "$(tail -c1 "$TMP/old")" ]; then old_eol=0; fi

awk -v want="$want" -v old_eol="$old_eol" '
  function keep(text, eol) { out[++o] = text; oeol[o] = eol }
  function keep_old(i) { keep(old[i], (i == on && !old_eol) ? 0 : 1) }
  BEGIN {
    n = split(want, w, " ")
    for (i = 1; i <= n; i++) { split(w[i], r, "-"); for (j = r[1] + 0; j <= r[2] + 0; j++) sel[j] = 1 }
  }
  NR == FNR {
    if ($0 ~ /^@@ /) {
      h++
      split(substr($2, 2), p, ",")
      a = p[1] + 0
      b = (index($2, ",") ? p[2] + 0 : 1)
      start[h] = (b == 0) ? a + 1 : a
      len[h] = 0
      next
    }
    if (!h) next
    if ($0 ~ /^\\/) { noeol[h, len[h]] = 1; next }
    line[h, ++len[h]] = $0
    next
  }
  { old[++on] = $0 }
  END {
    cur = 1
    for (k = 1; k <= h; k++) {
      while (cur < start[k]) keep_old(cur++)
      for (j = 1; j <= len[k]; j++) {
        t = substr(line[k, j], 1, 1)
        if (t == " ") keep_old(cur++)
        else if (t == "-") { num++; if (!(num in sel)) keep_old(cur); cur++ }
        else if (t == "+") { num++; if (num in sel) keep(substr(line[k, j], 2), noeol[k, j] ? 0 : 1) }
      }
    }
    while (cur <= on) keep_old(cur++)
    for (i = 1; i < o; i++) printf "%s\n", out[i]
    if (o) printf "%s%s", out[o], (oeol[o] ? "\n" : "")
  }
' "$TMP/diff" "$TMP/old" >"$TMP/out" || fail "cannot build the staged version of $full"

staged=$(git hash-object -w --no-filters "$TMP/out") || fail "cannot write the staged version of $full"
[ "$(git ls-files -s -- "$full")" = "$entry" ] || fail "$full changed in the index, list the lines again"
git update-index --add --cacheinfo "$mode,$staged,$full" || fail "cannot stage $full"

count=$(printf '%s\n' $want | awk -F- '{ for (i = $1; i <= $2; i++) s[i] } END { for (i in s) n++; print n }')
echo "staged $count of $total lines of $full"

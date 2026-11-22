#!/usr/bin/env bash
# spell-sync: merge Neovim's own spelling words (zg/zw) between the two
# repos, nixstick and the main repo nixos. Both get the union of both lists;
# a word removed with zug/zuw (Neovim comments it out as "#word") is dropped
# from both. Commit afterwards in each repo.
#
#   spell-sync              # finds the other repo under ~/GitHub
#   spell-sync <repo>       # or give its path

export LC_ALL=C # same order on every machine
list=dotfiles/nvim/spell/de.utf-8.add
header='# Own spelling words, added with zg in Neovim (one per line).'

here=$(realpath "$HOME/nixos")
if [[ $# -gt 0 ]]; then
  there=$(realpath "$1")
else
  there=
  while IFS= read -r f; do
    repo=$(realpath "${f%/"$list"}")
    if [[ $repo != "$here" ]]; then
      there=$repo
      break
    fi
  done < <(find "$HOME/GitHub" -maxdepth 6 -path "*/$list" 2>/dev/null)
fi

for repo in "$here" "$there"; do
  if [[ -z $repo || ! -f $repo/$list ]]; then
    echo "spell-sync: other repo not found (no $list under ~/GitHub); pass its path" >&2
    exit 1
  fi
done

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat "$here/$list" "$there/$list" >"$tmp/all"

# "#word" (no space) = removed in Neovim; "# text" = comment.
grep -E '^#[^ ]' "$tmp/all" | sed 's/^#//' | sort -u >"$tmp/removed" || true
grep -Ev '^(#|[[:space:]]*$)' "$tmp/all" | sort -u >"$tmp/words" || true
{
  echo "$header"
  comm -23 "$tmp/words" "$tmp/removed"
} >"$tmp/merged"

for repo in "$here" "$there"; do
  if cmp -s "$tmp/merged" "$repo/$list"; then
    echo "unchanged: $repo"
  else
    cp "$tmp/merged" "$repo/$list"
    echo "updated:   $repo"
    git -C "$repo" --no-pager diff --stat -- "$list"
  fi
done
echo "$(($(wc -l <"$tmp/merged") - 1)) words. Commit in each updated repo."

#!/usr/bin/env bash
# Focus the next (or with --prev the previous) window on any tag, switching to
# its tag first. Bound to Super+Tab / Super+Shift+Tab in nixos-mango/desktop.nix.
# mmsg comes with Mango (programs.mango), so it is already on PATH.
set -euo pipefail

step=1
[[ ${1:-} == --prev ]] && step=-1

# Windows sorted by tag, then by id; minimized and scratchpad windows are left out.
mapfile -t wins < <(
  mmsg get all-clients | jq -r '
    [.clients[]
      | select((.is_minimized or .is_scratchpad or .is_namedscratchpad) | not)
      | {id, tag: (.tags[0] // 0), focused: .is_focused}]
    | sort_by(.tag, .id)[]
    | "\(.id) \(.tag) \(.focused)"'
)
((${#wins[@]})) || exit 0

cur=-1
for i in "${!wins[@]}"; do
  [[ ${wins[i]} == *" true" ]] && cur=$i
done
((cur < 0 && step < 0)) && cur=0

read -r id tag _ <<<"${wins[(cur + step + ${#wins[@]}) % ${#wins[@]}]}"
((tag > 0)) && mmsg dispatch "view,$tag,0" >/dev/null
mmsg dispatch "focusid,$id" >/dev/null

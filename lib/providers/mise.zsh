# mise outdated-tool provider (table parse, no jq).
# Upgrade: mise upgrade <tool> (no --bump — keeps the requested version range).

_zpun_provider_mise() {
  emulate -L zsh
  setopt local_options

  (( $+commands[mise] )) || return 0

  local raw line name current latest
  # Prefer --no-header when available; otherwise skip the header by pattern.
  if mise outdated --help 2>/dev/null | grep -q -- '--no-header'; then
    raw=$(mise outdated --no-header 2>/dev/null) || return 0
  else
    raw=$(mise outdated 2>/dev/null) || return 0
  fi
  [[ -n $raw ]] || return 0

  while IFS= read -r line; do
    [[ -n $line && $line != Plugin* && $line != TOOL* && $line != ---* ]] || continue
    # name  requested  current  latest
    if [[ $line =~ '^[[:space:]]*([A-Za-z0-9_@./+-]+)[[:space:]]+[^[:space:]]+[[:space:]]+([^[:space:]]+)[[:space:]]+([^[:space:]]+)' ]]; then
      name=${match[1]}; current=${match[2]}; latest=${match[3]}
      [[ $current != "$latest" ]] || continue
      print -r -- "${name}"$'\t'"${current}"$'\t'"${latest}"
    fi
  done <<< "$raw" | _zpun_filter_by_allowlist mise
}

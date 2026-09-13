# Go binaries under $GOBIN via pure `go` (no third-party tools).
# Never name a local `path` — it is tied to PATH in zsh.

# Resolve go binary and GOBIN dir into goexe / gobin (caller locals).
_zpun_gobin_setup() {
  goexe=$(whence -p go 2>/dev/null) || return 1
  [[ -x $goexe ]] || return 1
  if [[ -n ${GOBIN:-} ]]; then
    gobin=$GOBIN
  else
    gobin=$("$goexe" env GOBIN 2>/dev/null)
    [[ -n $gobin ]] || gobin=$("$goexe" env GOPATH 2>/dev/null | cut -d: -f1)/bin
  fi
  [[ -d $gobin ]]
}

# From `go version -m` output → print "import_path\tversion" or fail.
_zpun_gobin_parse_buildinfo() {
  local raw=$1 line rest import_path= current=
  for line in ${(f)raw}; do
    case $line in
      *$'\tpath\t'*) import_path=${line#*$'\tpath\t'} ;;
      *$'\tmod\t'*)
        rest=${line#*$'\tmod\t'}
        [[ -n $import_path ]] || import_path=${rest%%$'\t'*}
        rest=${rest#*$'\t'}
        current=${rest%%$'\t'*}
        ;;
    esac
  done
  [[ -n $import_path && -n $current && $current != '(devel)' && $current != devel* ]] || return 1
  print -r -- "${import_path}"$'\t'"${current}"
}

# Latest module version for an import path (falls back to parent module).
_zpun_gobin_latest() {
  local goexe=$1 import_path=$2 latest mod
  latest=$("$goexe" list -m -f '{{.Version}}' "${import_path}@latest" 2>/dev/null) || true
  if [[ -z $latest ]]; then
    mod=${import_path%/cmd/*}
    [[ $mod == $import_path ]] && mod=${import_path%/*}
    [[ -n $mod && $mod != $import_path ]] && \
      latest=$("$goexe" list -m -f '{{.Version}}' "${mod}@latest" 2>/dev/null) || true
  fi
  [[ -n $latest ]] && print -r -- "$latest"
}

_zpun_provider_go() {
  emulate -L zsh
  setopt local_options null_glob

  local goexe gobin bin name info import_path current latest
  local -a rows

  _zpun_gobin_setup || return 0

  rows=()
  for bin in "$gobin"/*(N.); do
    [[ -x $bin && -f $bin && ${bin:t} != .* ]] || continue
    name=${bin:t}
    info=$(_zpun_gobin_parse_buildinfo "$("$goexe" version -m "$bin" 2>/dev/null)") || continue
    import_path=${info%%$'\t'*}; current=${info##*$'\t'}
    latest=$(_zpun_gobin_latest "$goexe" "$import_path") || continue
    [[ $current != "$latest" ]] || continue
    rows+=("${name}"$'\t'"${current}"$'\t'"${latest}")
  done

  (( ${#rows} )) || return 0
  print -r -- "${(F)rows}" | _zpun_filter_by_allowlist go
}

# Shared by _zpun_run_upgrade: resolve import path for a binary name under GOBIN.
_zpun_gobin_import_path() {
  local pkg=$1 goexe gobin raw info
  _zpun_gobin_setup || return 1
  [[ -x "$gobin/$pkg" ]] || return 1
  raw=$("$goexe" version -m "$gobin/$pkg" 2>/dev/null) || return 1
  info=$(_zpun_gobin_parse_buildinfo "$raw") || return 1
  print -r -- "${info%%$'\t'*}"
}

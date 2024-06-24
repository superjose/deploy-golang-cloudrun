generate_random_number() {
  local min=${1:-0}
  local max=${2:-100}
  echo $((min + RANDOM % (max - min + 1)))
}

update_config() {
   local config_path="$(pwd)/config.json"  
   local key="$1"
   local value="$2"

   jq "$key |= \"$value\"" "$config_path" > temp.json
   mv temp.json "$config_path"
}

failwith() { { echo -n "error: "; printf "%s\n" "$@"; } 1>&2; exit 1; }

# https://codereview.stackexchange.com/a/279533/103073
rpath() { # mimics a sane `realpath` for insane OSs that lack one
  local relbase="" relto=""
  while [[ x"${1-}" = x-* ]]; do case "$1" in
    ( "--relative-base="* ) relbase="$(rpath ${1#*=})" ;;
    ( "--relative-to="* )   relto="$(rpath ${1#*=})" ;;
    ( * ) failwith "unrecognized option '$1'"
  esac; shift; done
  if [[ "$#" -eq 0 ]]; then failwith "missing operand"; fi
  if [[ -n "$relto" && -n "$relbase" && "${relto#"$relbase/"}" = "$relto" ]]; then
    # relto is not a subdir of relbase => ignore both
    relto="" relbase=""
  elif [[ -z "$relto" && -n "$relbase" ]]; then
    # relbase is set but relto isn't => set relto from relbase to simplify
    relto="$relbase"
  fi
  local p d f n=0 up common PWD0="$PWD"
  for p in "$@"; do
    cd "$PWD0"
    while (( n++ < 50 )); do
      d="$(dirname "$p")"
      if [[ ! -e "$d" ]]; then failwith "$p: No such file or directory"; fi
      if [[ ! -d "$d" ]]; then failwith "$p: Not a directory"; fi
      cd -P "$d"
      f="$(basename "$p")"
      if [[ -h "$f" ]]; then p="$(readlink "$f")"; continue; fi
      # done getting the realpath
      local r="$PWD/$f"
      if [[ -n "$relto" && ( -z "$relbase" || "${r#"$relbase/"}" != "$r" ) ]]; then
        common="$relto" up=""
        while [[ "${r#"$common/"}" = "$r" ]]; do
          common="${common%/*}" up="..${up:+"/$up"}"
        done
        if [[ "$common" != "/" ]]; then
          r="${up:+"$up"/}${r#"$common/"}"
        fi
      fi
      cd "$PWD0"; echo "$r"; continue 2
    done
    cd "$PWD0"; failwith "$1: Too many levels of symbolic links"
  done
}
#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=.agents/skills/linting-rust-projects/scripts/config.sh
source "$script_dir/config.sh"

if [[ ${AMP_ORB:-} != 1 ]]; then
  echo "error: the cargo-lint bundle is supported only inside an Amp orb" >&2
  exit 1
fi
if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
  echo "error: unsupported platform; expected Linux x86_64" >&2
  exit 1
fi
glibc_version=$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')
if [[ -z $glibc_version ]] || [[ $(printf '%s\n' 2.36 "$glibc_version" | sort -V | head -1) != 2.36 ]]; then
  echo "error: unsupported libc; glibc 2.36 or newer is required" >&2
  exit 1
fi
if [[ $CARGO_LINT_SHA256 == TO_BE_GENERATED ]]; then
  echo "error: the pinned cargo-lint release checksum has not been configured" >&2
  exit 1
fi

cache_base=${XDG_CACHE_HOME:-"$HOME/.cache"}/cargo-lint
install_dir="$cache_base/$CARGO_LINT_VERSION/$CARGO_LINT_TARGET"
bundle_root="cargo-lint-${CARGO_LINT_VERSION}-${CARGO_LINT_TARGET}"
archive="$install_dir/$CARGO_LINT_ASSET"

verify_cache() {
  [[ -f $archive && -d $install_dir/$bundle_root ]] || return 1
  printf '%s  %s\n' "$CARGO_LINT_SHA256" "$archive" | sha256sum --check --status || return 1

  local trusted_sums
  trusted_sums=$(mktemp)
  if ! tar -xOzf "$archive" "$bundle_root/FILESUMS" >"$trusted_sums"; then
    rm -f -- "$trusted_sums"
    return 1
  fi
  if ! (cd "$install_dir/$bundle_root" && sha256sum --check --status "$trusted_sums"); then
    rm -f -- "$trusted_sums"
    return 1
  fi
  rm -f -- "$trusted_sums"
}

if verify_cache; then
  printf '%s\n' "$install_dir/$bundle_root/bin"
  exit 0
fi

umask 077
mkdir -p "$cache_base/$CARGO_LINT_VERSION"
lock_dir="$cache_base/$CARGO_LINT_VERSION/.install-$CARGO_LINT_TARGET.lock"
lock_acquired=
for _ in {1..120}; do
  if mkdir "$lock_dir" 2>/dev/null; then
    lock_acquired=1
    break
  fi
  sleep 0.25
done
if [[ $lock_acquired != 1 ]]; then
  echo "error: timed out waiting for the cargo-lint cache lock" >&2
  exit 1
fi
staging_dir=
trap 'rm -rf -- "$staging_dir" "$lock_dir"' EXIT

# Another process may have completed installation while this process waited.
if verify_cache; then
  printf '%s\n' "$install_dir/$bundle_root/bin"
  exit 0
fi

rm -rf -- "$install_dir"
staging_dir=$(mktemp -d "$cache_base/$CARGO_LINT_VERSION/.staging.XXXXXX")
staging_archive="$staging_dir/$CARGO_LINT_ASSET"
curl \
  --fail \
  --location \
  --proto '=https' \
  --retry 3 \
  --silent \
  --show-error \
  --output "$staging_archive" \
  "$CARGO_LINT_RELEASE_BASE_URL/$CARGO_LINT_ASSET"
printf '%s  %s\n' "$CARGO_LINT_SHA256" "$staging_archive" | sha256sum --check --status || {
  echo "error: cargo-lint release checksum mismatch" >&2
  exit 1
}

tar -xzf "$staging_archive" -C "$staging_dir"
(
  cd "$staging_dir/$bundle_root"
  sha256sum --check --status FILESUMS
  for binary in cargo-lint cargo-dequalify cargo-pedantic-lite cargo-myfmt; do
    [[ -x bin/$binary ]]
  done
)
mkdir -p "$(dirname -- "$install_dir")"
mv -- "$staging_dir" "$install_dir"
staging_dir=

printf '%s\n' "$install_dir/$bundle_root/bin"

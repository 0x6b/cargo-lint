#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=release/versions.env
source "$repo_root/release/versions.env"

dist_dir=${1:-"$repo_root/dist"}
asset="cargo-lint-${BUNDLE_VERSION}-${TARGET}.tar.gz"
expected_file="$repo_root/release/cargo-lint-${BUNDLE_VERSION}-${TARGET}.sha256"

if grep -q '^TO_BE_GENERATED ' "$expected_file"; then
  echo "error: expected release checksum has not been recorded in $expected_file" >&2
  exit 1
fi

(
  cd "$dist_dir"
  sha256sum --check "$expected_file"
)

members=$(tar -tzf "$dist_dir/$asset")
expected_root="cargo-lint-${BUNDLE_VERSION}-${TARGET}"
if grep -Ev "^${expected_root}/(bin/(cargo-lint|cargo-dequalify|cargo-pedantic-lite|cargo-myfmt)|LICENSES/[^/]+|VERSIONS.txt|FILESUMS)$" <<<"$members" \
  | grep -Ev "^${expected_root}/(bin|LICENSES)/?$|^${expected_root}/?$"; then
  echo "error: release archive contains an unexpected path" >&2
  exit 1
fi

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT
tar -xzf "$dist_dir/$asset" -C "$tmp_dir"
(
  cd "$tmp_dir/$expected_root"
  sha256sum --check FILESUMS
  for binary in cargo-lint cargo-dequalify cargo-pedantic-lite cargo-myfmt; do
    test -x "bin/$binary"
  done
  bin/cargo-dequalify dequalify --help >/dev/null

  mock_bin="$tmp_dir/mock-bin"
  mkdir "$mock_bin"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$mock_bin/cargo"
  chmod +x "$mock_bin/cargo"
  PATH="$mock_bin:$PATH" bin/cargo-pedantic-lite pedantic-lite >/dev/null
  PATH="$mock_bin:$PATH" bin/cargo-myfmt myfmt >/dev/null
  PATH="$mock_bin:$PATH" bin/cargo-lint lint >/dev/null
)

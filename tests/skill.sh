#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

skill="$tmp_dir/skill"
cp -R "$repo_root/.agents/skills/linting-rust-projects" "$skill"
fixture_root="$tmp_dir/fixture/cargo-lint-v9.9.9-x86_64-unknown-linux-gnu"
mkdir -p "$fixture_root/bin" "$fixture_root/LICENSES"
for binary in cargo-lint cargo-dequalify cargo-pedantic-lite cargo-myfmt; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$fixture_root/bin/$binary"
  chmod +x "$fixture_root/bin/$binary"
done
printf 'test\n' >"$fixture_root/LICENSES/test-LICENSE"
(
  cd "$fixture_root"
  find bin LICENSES -type f -print0 | sort -z | xargs -0 sha256sum > FILESUMS
)
fixture_archive="$tmp_dir/cargo-lint-v9.9.9-x86_64-unknown-linux-gnu.tar.gz"
tar -C "$tmp_dir/fixture" -czf "$fixture_archive" "$(basename -- "$fixture_root")"
fixture_sha=$(sha256sum "$fixture_archive" | awk '{print $1}')

cat >"$skill/scripts/config.sh" <<EOF
#!/usr/bin/env bash
CARGO_LINT_VERSION=v9.9.9
CARGO_LINT_TARGET=x86_64-unknown-linux-gnu
CARGO_LINT_ASSET=cargo-lint-v9.9.9-x86_64-unknown-linux-gnu.tar.gz
CARGO_LINT_SHA256=$fixture_sha
CARGO_LINT_RELEASE_BASE_URL=https://example.invalid/releases/v9.9.9
EOF

mock_bin="$tmp_dir/mock-bin"
mkdir "$mock_bin"
cat >"$mock_bin/curl" <<EOF
#!/usr/bin/env bash
set -eu
while [[ \$# -gt 0 ]]; do
  if [[ \$1 == --output ]]; then
    cp "$fixture_archive" "\$2"
    exit 0
  fi
  shift
done
exit 1
EOF
chmod +x "$mock_bin/curl"

export AMP_ORB=1
export XDG_CACHE_HOME="$tmp_dir/cache"
PATH="$mock_bin:$PATH" "$skill/scripts/install.sh" >"$tmp_dir/bin-path"
bundle_bin=$(cat "$tmp_dir/bin-path")
test -x "$bundle_bin/cargo-lint"

# A warm cache is verified and does not download again.
printf '#!/usr/bin/env bash\nexit 99\n' >"$mock_bin/curl"
PATH="$mock_bin:$PATH" "$skill/scripts/install.sh" >"$tmp_dir/bin-path-warm"
cmp "$tmp_dir/bin-path" "$tmp_dir/bin-path-warm"

# Corruption is detected and repaired from a checksum-verified archive download.
printf 'tampered\n' >>"$bundle_bin/cargo-lint"
cat >"$mock_bin/curl" <<EOF
#!/usr/bin/env bash
set -eu
while [[ \$# -gt 0 ]]; do
  if [[ \$1 == --output ]]; then
    cp "$fixture_archive" "\$2"
    exit 0
  fi
  shift
done
exit 1
EOF
chmod +x "$mock_bin/curl"
PATH="$mock_bin:$PATH" "$skill/scripts/install.sh" >/dev/null
if grep -q tampered "$bundle_bin/cargo-lint"; then
  echo "installer did not repair a corrupted cached executable" >&2
  exit 1
fi

# The runner performs all preflight checks and invokes cargo lint with its arguments.
cat >"$mock_bin/cargo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CARGO_TEST_LOG"
exit 0
EOF
chmod +x "$mock_bin/cargo"
export CARGO_TEST_LOG="$tmp_dir/cargo.log"
PATH="$mock_bin:$PATH" "$skill/scripts/run.sh" --workspace 2>"$tmp_dir/run.err"
grep -Fx -- '--version' "$CARGO_TEST_LOG"
grep -Fx -- 'clippy --version' "$CARGO_TEST_LOG"
grep -Fx -- '+nightly fmt --version' "$CARGO_TEST_LOG"
grep -Fx -- 'lint --workspace' "$CARGO_TEST_LOG"
grep -q 'rewrites the working tree' "$tmp_dir/run.err"
grep -q 'working tree is already dirty' "$tmp_dir/run.err"

if AMP_ORB='' PATH="$mock_bin:$PATH" "$skill/scripts/install.sh" >/dev/null 2>&1; then
  echo "installer unexpectedly accepted a non-orb environment" >&2
  exit 1
fi

echo "skill tests: OK"

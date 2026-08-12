#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=release/versions.env
source "$repo_root/release/versions.env"

if [[ $(uname -s) != Linux || $(uname -m) != x86_64 ]]; then
  echo "error: release bundles must be built on Linux x86_64" >&2
  exit 1
fi

output_dir=${1:-"$repo_root/dist"}
mkdir -p "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)

work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

export CARGO_HOME="$work_dir/cargo-home"
export CARGO_TARGET_DIR="$work_dir/target"
export RUSTFLAGS="-Ctarget-cpu=generic --remap-path-prefix=$work_dir=/cargo-lint-build"
export SOURCE_DATE_EPOCH=0

rustup run "$RUST_TOOLCHAIN" rustc --version >/dev/null

clone_at_revision() {
  local name=$1 repository=$2 revision=$3 destination="$work_dir/src/$1"

  git init -q "$destination"
  git -C "$destination" remote add origin "$repository"
  git -C "$destination" fetch -q --depth 1 origin "$revision"
  git -C "$destination" checkout -q --detach FETCH_HEAD
  [[ $(git -C "$destination" rev-parse HEAD) == "$revision" ]] || {
    echo "error: $name did not resolve to pinned revision $revision" >&2
    exit 1
  }
}

clone_at_revision cargo-dequalify "$CARGO_DEQUALIFY_REPOSITORY" "$CARGO_DEQUALIFY_REVISION"
clone_at_revision cargo-pedantic-lite "$CARGO_PEDANTIC_LITE_REPOSITORY" "$CARGO_PEDANTIC_LITE_REVISION"
clone_at_revision cargo-myfmt "$CARGO_MYFMT_REPOSITORY" "$CARGO_MYFMT_REVISION"

for package in cargo-dequalify cargo-pedantic-lite cargo-myfmt; do
  rustup run "$RUST_TOOLCHAIN" cargo build \
    --locked \
    --release \
    --target "$TARGET" \
    --manifest-path "$work_dir/src/$package/Cargo.toml"
done

bundle_name="cargo-lint-${BUNDLE_VERSION}-${TARGET}"
bundle_root="$work_dir/bundle/$bundle_name"
mkdir -p "$bundle_root/bin" "$bundle_root/LICENSES"
install -m 0755 "$repo_root/cargo-lint" "$bundle_root/bin/cargo-lint"
for package in cargo-dequalify cargo-pedantic-lite cargo-myfmt; do
  install -m 0755 \
    "$CARGO_TARGET_DIR/$TARGET/release/$package" \
    "$bundle_root/bin/$package"
  install -m 0644 \
    "$work_dir/src/$package/LICENSE" \
    "$bundle_root/LICENSES/$package-LICENSE"
done
install -m 0644 "$repo_root/LICENSE" "$bundle_root/LICENSES/cargo-lint-LICENSE"

cat >"$bundle_root/VERSIONS.txt" <<EOF
cargo-lint $BUNDLE_VERSION
cargo-dequalify $CARGO_DEQUALIFY_REVISION
cargo-pedantic-lite $CARGO_PEDANTIC_LITE_REVISION
cargo-myfmt $CARGO_MYFMT_REVISION
rust $RUST_TOOLCHAIN
target $TARGET
rustflags -Ctarget-cpu=generic --remap-path-prefix=<build-root>=/cargo-lint-build
EOF

(
  cd "$bundle_root"
  find bin LICENSES -type f -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum > FILESUMS
)

archive="$output_dir/$bundle_name.tar.gz"
tar \
  --sort=name \
  --format=ustar \
  --mtime='@0' \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -C "$work_dir/bundle" \
  -cf - "$bundle_name" \
  | gzip -n -9 >"$archive"

(
  cd "$output_dir"
  sha256sum "$(basename -- "$archive")" > SHA256SUMS
)

printf 'Created %s\n' "$archive"
cat "$output_dir/SHA256SUMS"

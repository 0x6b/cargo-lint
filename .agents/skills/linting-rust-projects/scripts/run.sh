#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

require() {
  local description=$1
  shift
  if ! "$@" >/dev/null 2>&1; then
    echo "error: missing prerequisite: $description" >&2
    exit 1
  fi
}

require "Cargo" cargo --version
require "Clippy (install with: rustup component add clippy)" cargo clippy --version
require "nightly rustfmt (install with: rustup toolchain install nightly --component rustfmt)" \
  cargo +nightly fmt --version

echo "WARNING: cargo lint rewrites the working tree using dequalify, Clippy fixes, and nightly rustfmt." >&2
if git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  && [[ -n $(git status --porcelain --untracked-files=normal) ]]; then
  echo "WARNING: the working tree is already dirty; existing changes may also be rewritten." >&2
fi

bundle_bin=$("$script_dir/install.sh")
PATH="$bundle_bin:$PATH" exec cargo lint "$@"

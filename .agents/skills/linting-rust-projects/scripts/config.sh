#!/usr/bin/env bash
# shellcheck disable=SC2034 # This file is sourced by install.sh.

CARGO_LINT_VERSION=v0.1.0
CARGO_LINT_TARGET=x86_64-unknown-linux-gnu
CARGO_LINT_ASSET="cargo-lint-${CARGO_LINT_VERSION}-${CARGO_LINT_TARGET}.tar.gz"
CARGO_LINT_SHA256=76c5b5852487b92268240f2677295bbab730b9a9b26fbb3360efcc25fcfa20cc
CARGO_LINT_RELEASE_BASE_URL="https://github.com/0x6b/cargo-lint/releases/download/${CARGO_LINT_VERSION}"

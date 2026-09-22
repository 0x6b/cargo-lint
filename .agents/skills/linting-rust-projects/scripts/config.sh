#!/usr/bin/env bash
# shellcheck disable=SC2034 # This file is sourced by install.sh.

CARGO_LINT_VERSION=v0.1.1
CARGO_LINT_TARGET=x86_64-unknown-linux-gnu
CARGO_LINT_ASSET="cargo-lint-${CARGO_LINT_VERSION}-${CARGO_LINT_TARGET}.tar.gz"
CARGO_LINT_SHA256=078c5fccacf910e6fca9cef63b6f8825e9e2081c100077ff135c786f5a0d4c9a
CARGO_LINT_RELEASE_BASE_URL="https://github.com/0x6b/cargo-lint/releases/download/${CARGO_LINT_VERSION}"

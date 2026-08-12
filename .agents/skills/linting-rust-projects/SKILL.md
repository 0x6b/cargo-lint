---
name: linting-rust-projects
description: Runs the opinionated 0x6b/cargo-lint rewrite, Clippy fix, and nightly rustfmt sequence in Rust workspaces. Use when asked to lint or automatically fix a Rust project in an Amp orb.
compatibility: Amp orbs (Debian 12, Linux x86_64) with Cargo, Clippy, and nightly rustfmt.
---

# Linting Rust Projects

Run the pinned `cargo-lint` bundle without compiling its Cargo subcommands during orb setup.

## Workflow

1. Tell the user that this command modifies the working tree. It runs dequalify, two Clippy fix passes, and nightly rustfmt, including when the tree is already dirty.
2. Do not stash, reset, restore, or commit existing changes.
3. From the Rust workspace root, run the bundled `scripts/run.sh` using its absolute path in this skill directory. Do not look for the script in the Rust project. For example:

   ```console
   /path/to/linting-rust-projects/scripts/run.sh
   ```

   Pass requested Cargo/Clippy arguments after the script name. The runner adds the verified bundle directory to `PATH` only for this invocation.
4. Report the command's exit status and inspect `git diff` so the user can review all rewrites.

The runner checks for Cargo, Clippy, and nightly rustfmt before downloading anything. If a prerequisite is absent, report the check that failed rather than falling back to a source build or silently installing a Rust toolchain.

Only Amp orbs running Linux x86_64 with glibc 2.36 or newer are supported. Do not bypass the platform check or use this release on macOS, Windows, ARM, or musl.

# cargo-lint

A cargo subcommand that runs a fixed sequence of lint and format tools in order:

1. [`cargo dequalify`](https://github.com/0x6b/cargo-dequalify) `-w --allow-dirty`: rewrites fully-qualified function calls into imported short names
2. [`cargo pedantic-lite`](https://github.com/0x6b/cargo-pedantic-lite) `--allow-dirty "$@"`: runs `cargo clippy --fix` with a curated subset of `clippy::pedantic` lints
3. `cargo clippy --fix --allow-dirty --all-targets --workspace "$@"`
4. [`cargo myfmt`](https://github.com/0x6b/cargo-myfmt): runs `cargo +nightly fmt` with a personal `rustfmt.toml` config, without polluting the project tree

> [!NOTE]
> Steps 2 and 3 are disjoint clippy runs: `cargo pedantic-lite` allows `clippy::all` and warns only its curated pedantic subset, while step 3 applies the default `clippy::all` lints across all targets and workspace members.

## Prerequisites

- `cargo` and `clippy`
- A nightly toolchain with `rustfmt` (used by `cargo myfmt`)
- The subcommands listed above, installable from their repositories:

  ```console
  $ cargo install --git https://github.com/0x6b/cargo-dequalify
  $ cargo install --git https://github.com/0x6b/cargo-pedantic-lite
  $ cargo install --git https://github.com/0x6b/cargo-myfmt
  ```

## Install

Put the script on your `PATH`. Cargo discovers executables named `cargo-<name>` as subcommands:

```console
$ ln -s "$(pwd)/cargo-lint" ~/.local/bin/cargo-lint
```

### Amp orb bundle

Tagged releases provide one checksum-pinned bundle for Amp orbs. The supported environment is Debian 12 on Linux x86_64 with glibc 2.36 or newer. The bundle contains `cargo-lint`, `cargo-dequalify`, `cargo-pedantic-lite`, and `cargo-myfmt`; macOS, Windows, ARM, and musl are not release targets.

The bundled wrappers still require Cargo, Clippy, and nightly rustfmt at runtime. The Amp skill in [`.agents/skills/linting-rust-projects`](.agents/skills/linting-rust-projects) checks these prerequisites, downloads the fixed release, verifies its SHA-256 checksum and cached files, and adds its `bin` directory to `PATH` only while running `cargo lint`. The skill directory can also be published unchanged as a top-level `linting-rust-projects` Global User Skill for use from other Rust repositories.

## Usage

```console
$ cargo lint
```

Extra arguments are forwarded unchanged to both `cargo pedantic-lite` and `cargo clippy`.

> [!WARNING]
> `cargo lint` rewrites the working tree and deliberately passes `--allow-dirty`. Review `git diff` after it runs.

## Release process

[`release/versions.env`](release/versions.env) pins the Rust toolchain and the complete Git commit SHA of each bundled Cargo subcommand. Build the deterministic archive, record its checksum in both the release checksum file and the skill configuration, then verify it:

```console
$ scripts/build-release-bundle.sh dist
$ scripts/verify-release-bundle.sh dist
$ tests/skill.sh
```

Pushing the matching version tag runs the release workflow and publishes the pre-verified archive plus `SHA256SUMS`. Published release assets must not be replaced; updates use a new version and checksum.

## License

MIT. See [LICENSE](LICENSE) for details.

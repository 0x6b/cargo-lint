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

## Usage

```console
$ cargo lint
```

Extra arguments are forwarded unchanged to both `cargo pedantic-lite` and `cargo clippy`.

## License

MIT. See [LICENSE](LICENSE) for details.

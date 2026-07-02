# tcsh

[tcsh](https://www.tcsh.org/) — an enhanced, fully compatible version of the Berkeley UNIX C shell (`csh`), with a command-line editor, programmable completion, spelling correction, history, and job control. A single self-contained binary, built natively for Linux, macOS, and Windows.

[![CI](https://github.com/unpins/tcsh/actions/workflows/tcsh.yml/badge.svg)](https://github.com/unpins/tcsh/actions)
![Linux](https://img.shields.io/badge/Linux-✓-success?logo=linux&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-✓-success?logo=apple&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-✓-success?logo=windows&logoColor=white)

Part of the [unpins](https://unpins.org) catalog; install it with [`unpin`](https://github.com/unpins/unpin): `unpin install tcsh`.

## Usage

Run `tcsh` with [unpin](https://github.com/unpins/unpin):

```bash
unpin tcsh                        # start an interactive shell
unpin tcsh script.csh             # run a script
unpin tcsh -c 'echo $version'
```

To install it onto your PATH:

```bash
unpin install tcsh
```

Programmable completion works out of the box — completions are defined at
runtime with the `complete` builtin, so nothing has to be on disk:

```tcsh
complete cd 'p/1/d/'              # complete only directories after cd
set autolist                     # list completions on ambiguity
```

## Man pages

The tcsh manual (`tcsh.1`) is embedded, so `unpin man tcsh` works offline.

## Build locally

```bash
nix build github:unpins/tcsh
./result/bin/tcsh -c 'echo $version'
```

Or run directly:

```bash
nix run github:unpins/tcsh -- -c 'echo hello from tcsh'
```

The first invocation will offer to add the [unpins.cachix.org](https://unpins.cachix.org) substituter so most pulls come pre-built.

## Manual download

The [Releases](https://github.com/unpins/tcsh/releases) page has standalone binaries for manual download.

## Build notes

- **Self-contained, no data files.** Unlike zsh, tcsh has no module system and
  no autoloaded function tree — completions are runtime `complete` builtins, not
  files — so the shell is already self-contained and needs no embedded
  filesystem.

- **NLS crash fix (musl).** A static build of `pkgsStatic.tcsh` segfaults at
  startup on *every* invocation: `nlsinit()` calls `catopen("tcsh")`, which
  fails when there are no `.cat` files on disk, and then passes the resulting
  `(nl_catd)-1` to `catgets()`. POSIX (and glibc/the BSDs) make `catgets()`
  return the default string for a bad descriptor; musl instead dereferences
  `(char *)-1` and crashes. `musl-catgets-guard.patch` guards tcsh's single
  catgets chokepoint (`xcatgets`), making the shell robust on musl while leaving
  real localization intact wherever the platform's `catgets()` is conformant.
  Messages are English on all targets (no catalogs are shipped on disk).

- **Static linking, every target.** Linux is static-musl (every arch); the
  binary carries a curated ncurses terminfo fallback so the command-line editor
  works with no `/usr/share/terminfo` on the host (`strace` shows zero
  `/nix/store` reads at runtime). macOS links only `libSystem` (`otool -L`
  confirms — ncurses and everything else is static).

- **Windows via Cosmopolitan.** mingw can't host tcsh (no `fork`, job control,
  or POSIX signals), so the Windows binary goes through cosmo. Two cosmo-
  specific build fixes: `_POSIX_VDISABLE` is pinned to a compile-time constant
  (cosmo exposes it as a runtime `extern const`, but tcsh seeds a file-scope
  array with it), and the shadow-password `lock` path is switched to plain
  `crypt` (Windows has no `/etc/shadow`). See `cosmo.nix`.

- **Tests.** tcsh's autotest suite isn't wired: its harness regenerates itself
  with `autom4te` (autoconf) and expects a pty/`expect` environment, neither
  available in the static-musl build sandbox. The release smoke test exercises
  the interpreter and the builtin `echo`.

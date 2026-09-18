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

- **Startup crash fixed.** Unpatched, the shell segfaulted at startup on
  *every* invocation when no message catalogs are on disk; this build fixes
  that. Messages are English on all targets (no catalogs are shipped on disk).

- **Static linking, every target.** Linux is static-musl (every arch); the
  binary carries a curated ncurses terminfo fallback so the command-line editor
  works with no `/usr/share/terminfo` on the host (`strace` shows zero
  `/nix/store` reads at runtime). macOS links only `libSystem` (`otool -L`
  confirms — ncurses and everything else is static).

- **Windows via Cosmopolitan.** mingw can't host tcsh (no `fork`, job control,
  or POSIX signals), so the Windows binary goes through cosmo. There the `lock`
  builtin checks the password with plain `crypt` (Windows has no `/etc/shadow`).

- **Tests.** tcsh's autotest suite isn't wired: its harness regenerates itself
  with `autom4te` (autoconf) and expects a pty/`expect` environment, neither
  available in the build sandbox. The release smoke test exercises
  the interpreter and the builtin `echo`.

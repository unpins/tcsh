{
  description = "tcsh as a single self-contained binary";

  nixConfig = {
    extra-substituters = [ "https://unpins.cachix.org" ];
    extra-trusted-public-keys = [ "unpins.cachix.org-1:DDaShjbZ8VvcqxeTcAU3kV9vxZQBlyb7V/uLBHfTynI=" ];
  };

  inputs.unpins-lib.url = "github:unpins/nix-lib";

  # tcsh (the enhanced Berkeley C shell) as a single self-contained static
  # binary. Unlike zsh it has no module system and no autoloaded function tree
  # — completions are runtime `complete` builtins, not files — so the shell is
  # already self-contained with no VFS. Two deltas vs nixpkgs pkgsStatic.tcsh:
  #
  #   - musl-catgets-guard.patch: pkgsStatic.tcsh segfaults at startup on EVERY
  #     invocation. tcsh's nlsinit() calls catopen("tcsh"), which fails in a
  #     single binary with no .cat files on disk, then passes the resulting
  #     (nl_catd)-1 to catgets(). POSIX (and glibc/BSD) make catgets() return
  #     the default string for a bad descriptor; musl instead dereferences
  #     (char *)-1 and crashes. The patch guards tcsh's single catgets chokepoint
  #     (xcatgets) — robust on musl, real localization preserved where the
  #     platform's catgets is conformant.
  #   - ncurses fallback-terminfo (tcsh's command-line editor looks up terminal
  #     capabilities via terminfo; baked fallbacks avoid reading host
  #     /usr/share/terminfo and a /nix/store ref) is now applied centrally to
  #     every engine ncurses in native-overlay/ncurses.nix — no per-package
  #     override (same for dash/nano).
  #
  # Messages are English on all targets: tcsh ships its catalogs in glibc/gencat
  # format, which musl's catgets cannot read (wrong magic) even when present, and
  # we ship no catalogs on disk anyway — so catopen always fails and the built-in
  # English strings are used. (Same English-only stance as dash/zsh.)
  #
  # Targets:
  #   - Linux (static-musl, every arch).
  #   - macOS (Mach-O, libSystem-only).
  #   - Windows (single PE .exe, built via Cosmopolitan): see cosmo.nix — mingw is a dead end for tcsh
  #     (needs fork/job-control/signals), cosmocc backs them.
  outputs = { self, unpins-lib }:
    let
      # Fallback terminfo is baked centrally for every engine ncurses, linux +
      # darwin (native-overlay/ncurses.nix), so p.ncurses already carries it.
      tcshBase = pkgs:
        let p = pkgs.pkgsStatic;
        in (p.tcsh.override { ncurses = p.ncurses; }).overrideAttrs (o: {
          patches = (o.patches or [ ]) ++ [ ./musl-catgets-guard.patch ];
          # Don't wire the native suite: tcsh's autotest harness regenerates
          # itself with autom4te (autoconf) and expects a pty/expect environment,
          # neither present in the static-musl build sandbox.
          doCheck = false;
        });
    in
    unpins-lib.lib.mkStandaloneFlake {
      inherit self;
      name = "tcsh";

      # Build via the unpin-llvm engine + emit a bitcode multicall module.
      engine = "unpin-llvm";
      multicall = {
        programs = [{ name = "tcsh"; }];
      };
      license = "BSD-2-Clause";

      # tcsh has --version; also exercise the interpreter to confirm argv
      # parsing and the builtin echo on every ABI (incl. the cosmo PE).
      smoke = [ "-f" "-c" "echo unpins-smoke-ok" ];
      smokePattern = "unpins-smoke-ok";

      # Windows via Cosmopolitan (mingw is a dead end for tcsh — needs
      # fork/job-control/signals). See cosmo.nix.
      windowsBuild = import ./cosmo.nix { inherit unpins-lib; };

      build = pkgs: tcshBase pkgs;
    };
}

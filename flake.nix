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
  # already self-contained with no VFS. Deltas vs nixpkgs pkgsStatic.tcsh:
  #
  #   - musl-catgets-guard.patch: pkgsStatic.tcsh segfaults at startup on EVERY
  #     invocation. tcsh's nlsinit() calls catopen("tcsh"), which fails in a
  #     single binary with no .cat files on disk, then passes the resulting
  #     (nl_catd)-1 to catgets(). POSIX (and glibc/BSD) make catgets() return
  #     the default string for a bad descriptor; musl instead dereferences
  #     (char *)-1 and crashes. The patch guards tcsh's single catgets chokepoint
  #     (xcatgets) — robust on musl, real localization preserved where the
  #     platform's catgets is conformant.
  #   - shell-path-bin-tcsh.patch: `$shell` defaults to /bin/tcsh, not the
  #     build's store path (the patch header has the why).
  #   - The terminfo fallback comes from the central ncurses
  #     (native-overlay/ncurses.nix).
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
      tcshBase = pkgs:
        pkgs.pkgsStatic.tcsh.overrideAttrs (o: {
          patches = (o.patches or [ ]) ++ [
            ./musl-catgets-guard.patch
            ./shell-path-bin-tcsh.patch
            ./tests-pwd-from-path.patch
          ];
          # The autotest suite regenerates itself with autom4te. filetest and
          # "Primary expressions" are left out: they chmod a file setuid,
          # which the build sandbox forbids.
          doCheck = pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform;
          nativeCheckInputs = (o.nativeCheckInputs or [ ]) ++ (with pkgs.buildPackages; [ autoconf perl getent ]);
          checkFlags = (o.checkFlags or [ ]) ++ [ "ENVCMD=env" ];
          # On darwin three tests read the home directory with dscl, which the
          # sandbox lacks; this one answers from the same passwd entry tcsh sees.
          preCheck = ''
            checkFlagsArray+=("TESTSUITEFLAGS=-k !filetest,!Primary")
          '' + pkgs.lib.optionalString pkgs.stdenv.buildPlatform.isDarwin ''
            mkdir -p "$TMPDIR/dscl-shim"
            printf '%s\n' '#!${pkgs.buildPackages.runtimeShell}' \
              'echo "NFSHomeDirectory: $(getent passwd "$(id -u)" | cut -d: -f6)"' \
              > "$TMPDIR/dscl-shim/dscl"
            chmod +x "$TMPDIR/dscl-shim/dscl"
            export PATH="$TMPDIR/dscl-shim:$PATH"
          '';
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
      # nixpkgs says bsd2; tcsh's Copyright file has the three-clause text.
      license = "BSD-3-Clause";

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

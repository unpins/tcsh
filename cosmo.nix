# tcsh via cosmoStaticCross (= pkgs.pkgsCross.cosmo) for Windows-x86_64.
#
# mingw is a dead end for tcsh (it needs fork(), job control and POSIX
# signals); cosmocc backs all three, so the Windows build goes through the
# cosmo cross stdenv, which auto-apelinks $out/bin/* (ELF -> PE32+, rename to
# <name>.exe) in fixupPhase.
#
# Same musl-catgets-guard.patch as the native build: cosmo's libc, like musl,
# is not guaranteed to tolerate catgets() on a failed descriptor, and tcsh's
# nlsinit() always calls it. The guard makes startup robust regardless; messages
# stay English (no .cat files on disk).
{ unpins-lib }:
pkgs:
let
  cosmoPkgs = unpins-lib.lib.cosmoStaticCross pkgs;
in
cosmoPkgs.tcsh.overrideAttrs (oa: {
  # findcmd-exe-lookup.patch: catalog programs install as `<name>.exe`
  # (cmd.exe/PowerShell find them via PATHEXT), but Cosmopolitan appends no
  # suffix during path resolution, so a bare `ls` typed at the tcsh prompt
  # never resolves. The patch teaches tcsh's exec chokepoint (texec) to retry
  # with `.exe` when the bare candidate fails ENOENT, as native Windows shells
  # do, keeping a single on-disk name. `__COSMOCC__`-guarded.
  patches = (oa.patches or [ ]) ++ [
    ./musl-catgets-guard.patch
    ./shell-path-bin-tcsh.patch
    ./cosmo-posix-vdisable.patch
    ./findcmd-exe-lookup.patch
  ];

  # cosmo ships <shadow.h> but not the getspnam() symbol, so configure sets
  # HAVE_SHADOW_H and tcsh's screen-`lock` auth path (tc.func.c auto_lock) pulls
  # in an undefined getspnam at link. Windows has no /etc/shadow anyway — tell
  # configure the header is absent so tcsh takes the plain crypt(pw_passwd)
  # branch (the lock feature still works against the regular passwd field).
  configureFlags = (oa.configureFlags or [ ]) ++ [ "ac_cv_header_shadow_h=no" ];

  # gcc-14 under cosmocc's default -std=gnu23 turns an implicit function
  # declaration into a hard error; tcsh's configure probes report several libc
  # functions present but cosmo's headers don't always declare them on the path
  # tcsh includes. Downgrade to a warning (same fix dash/zsh cosmo.nix use).
  env = (oa.env or { }) // {
    NIX_CFLAGS_COMPILE = builtins.concatStringsSep " " [
      (oa.env.NIX_CFLAGS_COMPILE or "")
      "-Wno-implicit-function-declaration"
    ];
  };
})

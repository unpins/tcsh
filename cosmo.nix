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
  patches = (oa.patches or [ ]) ++ [ ./musl-catgets-guard.patch ];

  # Cosmopolitan exposes _POSIX_VDISABLE as a runtime `extern const int` (its
  # termios layer normalizes it across hosts), NOT a compile-time constant. But
  # tcsh seeds the file-scope `ttychars[]` array with it (ed.init.c ~l.69-73),
  # which requires a constant expression → "error: unable to substitute
  # constant". Pin it to cosmo's actual runtime value (verified 0 via a cosmocc
  # probe) right after ed.init.c's includes, so the static initializer is
  # constant AND the runtime remap logic (ed.init.c l.158-162, comparing
  # ttychars against _POSIX_VDISABLE) still matches. Same shape as zsh's
  # RLIM_NLIMITS pin.
  postPatch = (oa.postPatch or "") + ''
    substituteInPlace ed.init.c \
      --replace '#include "ed.defns.h"' \
                '#include "ed.defns.h"
#ifdef __COSMOPOLITAN__
# undef _POSIX_VDISABLE
# define _POSIX_VDISABLE 0
#endif'

    # Windows command lookup: catalog programs install as `<name>.exe` hardlinks
    # (cmd.exe/PowerShell find them via PATHEXT), but Cosmopolitan does not append
    # an executable suffix during path resolution, so a bare `ls` typed at the
    # tcsh prompt never resolves. The patch teaches tcsh's exec chokepoint (texec)
    # to retry with `.exe` when the bare candidate fails ENOENT — mirroring native
    # Windows shells and keeping a single on-disk name (no `ls` + `ls.exe` pair).
    # `__COSMOCC__`-guarded, inert on the Linux/macOS static builds.
    patch -p1 < ${./findcmd-exe-lookup.patch}
  '';

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

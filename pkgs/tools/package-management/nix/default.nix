{ lib, stdenv, fetchurl, perl, curl, bzip2, sqlite, openssl ? null, xz
, pkgconfig, boehmgc, perlPackages, libsodium
, storeDir ? "/nix/store"
, stateDir ? "/nix/var"
}:

let

  common = { name, src }: stdenv.mkDerivation rec {
    inherit name src;

    outputs = [ "out" "dev" "man" "doc" ];

    nativeBuildInputs = [ perl pkgconfig ];

    buildInputs = [ curl openssl sqlite xz ]
      ++ lib.optional (stdenv.isLinux || stdenv.isDarwin) libsodium;

    propagatedBuildInputs = [ boehmgc ];

    # Note: bzip2 is not passed as a build input, because the unpack phase
    # would end up using the wrong bzip2 when cross-compiling.
    # XXX: The right thing would be to reinstate `--with-bzip2' in Nix.
    postUnpack =
      '' export CPATH="${bzip2.dev}/include"
         export LIBRARY_PATH="${bzip2.out}/lib"
         export CXXFLAGS="-Wno-error=reserved-user-defined-literal"
      '';

    configureFlags =
      ''
        --with-store-dir=${storeDir} --localstatedir=${stateDir} --sysconfdir=/etc
        --with-dbi=${perlPackages.DBI}/${perl.libPrefix}
        --with-dbd-sqlite=${perlPackages.DBDSQLite}/${perl.libPrefix}
        --with-www-curl=${perlPackages.WWWCurl}/${perl.libPrefix}
        --disable-init-state
        --enable-gc
      '';

    makeFlags = "profiledir=$(out)/etc/profile.d";

    installFlags = "sysconfdir=$(out)/etc";

    doInstallCheck = true;

    separateDebugInfo = stdenv.isLinux;

    crossAttrs = {
      postUnpack =
        '' export CPATH="${bzip2.crossDrv}/include"
           export NIX_CROSS_LDFLAGS="-L${bzip2.crossDrv}/lib -rpath-link ${bzip2.crossDrv}/lib $NIX_CROSS_LDFLAGS"
        '';

      configureFlags =
        ''
          --with-store-dir=${storeDir} --localstatedir=${stateDir}
          --with-dbi=${perlPackages.DBI}/${perl.libPrefix}
          --with-dbd-sqlite=${perlPackages.DBDSQLite}/${perl.libPrefix}
          --with-www-curl=${perlPackages.WWWCurl}/${perl.libPrefix}
          --disable-init-state
          --enable-gc
        '' + stdenv.lib.optionalString (
            stdenv.cross ? nix && stdenv.cross.nix ? system
        ) ''--with-system=${stdenv.cross.nix.system}'';

      doInstallCheck = false;
    };

    enableParallelBuilding = true;

    meta = {
      description = "Powerful package manager that makes package management reliable and reproducible";
      longDescription = ''
        Nix is a powerful package manager for Linux and other Unix systems that
        makes package management reliable and reproducible. It provides atomic
        upgrades and rollbacks, side-by-side installation of multiple versions of
        a package, multi-user package management and easy setup of build
        environments.
      '';
      homepage = http://nixos.org/;
      license = stdenv.lib.licenses.lgpl2Plus;
      maintainers = [ stdenv.lib.maintainers.eelco ];
      platforms = stdenv.lib.platforms.all;
    };
  };

in rec {

  nix = nixStable;

  nixStable = common rec {
    name = "nix-1.11.4";
    src = fetchurl {
      url = "http://nixos.org/releases/nix/${name}/${name}.tar.xz";
      sha256 = "937779ed2efaa3dec210250635401980acb99a6fea6d7374fbaea78231b36d34";
    };
  };

  nixUnstable = lib.lowPrio (common rec {
    name = "nix-2016-11-22";
    src = fetchurl {
      url = "https://static.domenkozar.com/nix-1.12pre4892_215b70f.tar.xz";
      sha256 = "0vi43zl25xygcvcfpa5wjk8vj0ll52m43fmycpx158yi28ry0ax8";
    };
  });

}

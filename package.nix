{
  alsa-lib,
  autoPatchelfHook,
  bash,
  bubblewrap,
  bzip2,
  db4,
  fetchurl,
  freetype,
  glib,
  glibcLocales,
  kdePackages,
  lib,
  libdrm,
  libxcrypt-legacy,
  locale,
  ncurses5,
  pkgsBuildBuild,
  python3,
  qt6,
  readline,
  sqlite,
  stdenv,
  tcl,
  xorg,
  ...
}@args:

let
  # Nix's seccomp settings (via the syscall-filter nix.conf option) disallow
  # creating setuid/setgid binaries, so we shim in our own chmod that unsets
  # the setuid/setgid bits in all chmod calls.
  fixChmod = pkgsBuildBuild.callPackage (
    { stdenv }:
    stdenv.mkDerivation {
      name = "quartus-installer-fix-chmod.so";
      buildCommand = ''
        $CC -Wall -fPIC -shared -ldl -o $out ${./chmod-fix.c}
      '';
    }
  ) { };

  # The quartus installer assumes it is running on an FHS-compliant Linux
  # system.
  installerFhsEnv = pkgsBuildBuild.callPackage (
    { buildFHSEnv, writeScript }:
    buildFHSEnv {
      name = "quartus-installer-fhs-env";
      extraBwrapArgs = [ "--bind /nix /nix" ]; # ensure $out is read-write
      runScript = writeScript "quartus-installer" ''
        env LD_PRELOAD=${fixChmod} "$@"
      '';
    }
  ) { };
in
stdenv.mkDerivation (_: {
  pname = "QuartusProProgrammer";
  version = args._source.version;

  strictDeps = true;

  dontUnpack = true;
  dontConfigure = true;
  dontInstall = true;

  src = fetchurl { inherit (args._source) url hash; };

  nativeBuildInputs = [
    bubblewrap
    qt6.wrapQtAppsNoGuiHook
    autoPatchelfHook
  ];

  # TODO(jared): these don't exist anywhere in nixpkgs
  autoPatchelfIgnoreMissingDeps = [
    "libQt6DeclarativeOpcua.so.6"
    "libQt6OpcUa.so.6"
    "libcbx_mgl.so"
    "libcbx_stratixii.so"
    "libcrypto.so.1.0.0"
    "libda_dut.so"
    "libmat.so"
    "libmex.so"
    "libmx.so"
    "libneto_qneto.so"
    "libnlv_nlvcc.so"
    "libperiph_blc.so"
    "libreadline.so.6"
    "libresr_qdbvq.so"
    "libssl.so.1.0.0"
  ];

  buildInputs = [
    alsa-lib
    bash
    bzip2
    db4
    freetype
    glib
    kdePackages.qtcharts
    kdePackages.qtdeclarative
    kdePackages.qtlottie
    kdePackages.qtmultimedia
    kdePackages.qtquicktimeline
    kdePackages.qtremoteobjects
    kdePackages.qtscxml
    kdePackages.qtsensors
    kdePackages.qtspeech
    kdePackages.qtvirtualkeyboard
    kdePackages.qtwebchannel
    kdePackages.qtwebsockets
    libdrm
    libxcrypt-legacy
    ncurses5
    python3
    readline
    sqlite
    tcl
    xorg.libICE
    xorg.libSM
    xorg.libX11
    xorg.libXext
  ];

  buildPhase = ''
    runHook preBuild

    mkdir -p $out/nix-support
    echo 'export PATH=$PATH:${placeholder "out"}/qprogrammer/quartus/bin' >$out/nix-support/setup-hook
    ${lib.getExe installerFhsEnv} /lib64/ld-linux-x86-64.so.2 $src --accept_eula 1 --mode unattended --unattendedmodeui none --installdir $out

    qenv=$out/qprogrammer/quartus/adm/qenv.sh
    linenr=$(grep --line-number '^[^#]' $qenv | head -n1 | cut -d':' -f1)

    # Add missing utilities to PATH, injecting a line on the first
    # non-commented line in the entrypoint qenv.sh file that prepends the
    # current PATH.
    sed -i "''${linenr}iPATH=${lib.makeBinPath [ locale ]}:\$PATH\n" $qenv

    # Add locales that would otherwise be missing in a sandboxed environment.
    # This probably isn't necessary, however it prevents warnings from showing
    # up during builds.
    sed -i "''${linenr}iexport LOCALE_ARCHIVE=${glibcLocales}/lib/locale/locale-archive\n" $qenv

    runHook postBuild
  '';

  meta.platforms = [ "x86_64-linux" ];
})

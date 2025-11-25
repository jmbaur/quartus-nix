{
  buildFHSEnv,
  fetchurl,
  lib,
  pkgsBuildBuild,
  runCommand,
  runtimeShell,
}:

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
      runScript = writeScript "quartus-installer" ''
        env LD_PRELOAD=${fixChmod} "$@"
      '';
    }
  ) { };
in
lib.makeOverridable (
  {
    pname,
    version,
    source,
    disableComponents ? [ ],
  }:

  let
    executableName = "quartus-shell";

    # buildFHSEnv will pass through the host's /nix/store, so we can make our
    # lives easier by doing as little as possible ahead of time when performing
    # the quartus "installation", then re-organize things to work later.
    installation =
      runCommand "${pname}-installation-${version}"
        {
          src = fetchurl { inherit (source) url hash; };
        }
        # We allow `src` to either be a tarball or the self-extracting
        # executable itself. This allows for us to support installations of
        # quartus-pro-programmer, which is not a tarball.
        ''
          if [[ $(head --bytes=4 $src) == $(printf "\x7fELF") ]]; then
            run_cmd=$src
          else
            tar -xvf $src

            # There will be one file called setup.sh or setup_pro.sh in the case of quartus prime pro
            run_cmd=$(grep 'export CMD_NAME' setup*.sh | sed 's/.*SCRIPT_PATH\/\(.*\)"/\1/')
          fi

          ${lib.getExe installerFhsEnv} /lib64/ld-linux-x86-64.so.2 $run_cmd \
          --accept_eula 1 \
          --mode unattended --unattendedmodeui none \
          --installdir $out \
          ${lib.optionalString (
            disableComponents != [ ]
          ) "--disable-components ${lib.concatStringsSep "," disableComponents}"}
        '';
  in
  buildFHSEnv {
    inherit pname version executableName;

    extraBwrapArgs = [ "--ro-bind-try /etc/jtagd /etc/jtagd" ];

    # Ensure software like lmutil can run.
    extraBuildCommands = ''
      ln -s /lib64/ld-linux-x86-64.so.2 $out/usr/lib64/ld-lsb-x86-64.so.3
    '';

    extraInstallCommands = ''
      progs_to_wrap=(
        "${installation}"/qprogrammer/syscon/bin/*
        "${installation}"/qprogrammer/quartus/bin/*
        "${installation}"/quartus/bin/*
        "${installation}"/quartus/sopc_builder/bin/qsys-{generate,edit,script}
        "${installation}"/questa_fse/bin/*
        "${installation}"/questa_fse/linux_x86_64/lmutil
      )

      wrapper=$out/bin/${executableName}
      progs_wrapped=()
      for prog in ''${progs_to_wrap[@]}; do
        relname="''${prog#"${installation}/"}"
        bname="$(basename "$relname")"
        wrapped="$out/$relname"
        progs_wrapped+=("$wrapped")
        mkdir -p "$(dirname "$wrapped")"
        echo "#!${runtimeShell}" >> "$wrapped"
        echo "exec $wrapper $prog \"\$@\"" >> "$wrapped"
      done

      cd $out
      chmod +x ''${progs_wrapped[@]}
      # link into $out/bin so executables become available on $PATH
      ln --symbolic --relative --target-directory ./bin ''${progs_wrapped[@]}
    '';

    # Directly passthrough commands from the outer enviroment.
    runScript = "";

    targetPkgs =
      pkgs: with pkgs; [
        acl
        alsa-lib
        attr
        bash
        bzip2
        db4
        expat
        fontconfig
        freetype
        glib
        gmp
        kdePackages.qtbase
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
        libGL
        libdrm
        libxcrypt-legacy
        libxkbcommon
        ncurses5
        python3
        readline
        sqlite
        tcl
        tclPackages.tk
        udev
        xcb-util-cursor
        xorg.libICE
        xorg.libSM
        xorg.libX11
        xorg.libXau
        xorg.libXdmcp
        xorg.libXext
        xorg.libXft
        xorg.libxcb
        xorg.xcbutil
        xorg.xcbutilimage
        xorg.xcbutilkeysyms
        xorg.xcbutilrenderutil
        xorg.xcbutilwm
        zlib
      ];

    passthru = { inherit installation; };
    meta.platforms = [ "x86_64-linux" ];
  }
)

{
  buildFHSEnv,
  fetchurl,
  fetchzip,
  lib,
  makeDesktopItem,
  ncurses5,
  pkgsBuildBuild,
  runtimeShell,
}:

let
  desktopItem = makeDesktopItem {
    name = "quartus";
    desktopName = "Quartus";
    exec = "quartus";
    icon = "quartusii";
    terminal = false;
    type = "Application";
    categories = [ "Development" ];
    startupWMClass = "Quartus";
    startupNotify = true;
  };

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
  }:

  let
    executableName = "quartus-shell";

    # buildFHSEnv will pass through the host's /nix/store, so we can make our
    # lives easier by doing as little as possible ahead of time when
    # performing the quartus "installation", then re-organize things to work
    # later. We also do all this work in `postFetch` of `fetchurl` so that we
    # don't need _two_ large derivations (one for the downloaded tarball and
    # another for the installation).
    installation = fetchurl {
      name = "${pname}-installation-${version}";

      inherit (source) url hash;

      recursiveHash = true;
      downloadToTemp = true;

      postFetch =
        # We allow `downloadedFile` to either be a tarball or the
        # self-extracting executable itself. This allows for us to support
        # installations of quartus-pro-programmer, which is not a tarball.
        ''
          if [[ $(head --bytes=4 $downloadedFile) == $(printf "\x7fELF") ]]; then
            chmod +x $downloadedFile
            run_cmd=$downloadedFile
          else
            tar -xvf $downloadedFile

            # There will be one file called setup.sh or setup_pro.sh in the case of quartus prime pro
            run_cmd=$(grep 'export CMD_NAME' setup*.sh | sed 's/.*SCRIPT_PATH\/\(.*\)"/\1/')
          fi

          installer_args=(
            "--accept_eula" "1"
            "--mode" "unattended"
            "--unattendedmodeui" "none"
            "--installdir" "$out"
          )

          ${lib.getExe installerFhsEnv} /lib64/ld-linux-x86-64.so.2 $run_cmd "''${installer_args[@]}"

          # Apply patches, if there are any
          ${lib.concatMapStringsSep "\n" (fetchzipArgs: ''
            (
              patch_args=()
              if [[ -e $out/qprogrammer ]]; then
                patch_args+=("--patch_to" "qprogrammer")
              fi

              ${lib.getExe installerFhsEnv} /lib64/ld-linux-x86-64.so.2 ${fetchzip fetchzipArgs}/*linux.run "''${installer_args[@]}" "''${patch_args[@]}"
            )
          '') (source.patches or [ ])}

          # No need for this, it's just another chance for
          # non-reproducibility/self-referencing to leak in.
          rm -rf $out/logs $out/uninstall

          # The .sopc_builder file references $out, which is disallowed in
          # FODs. Since we provide a reference to the installation from within
          # the FHS env at /quartus, we can point to that here.
          if [[ -f $out/quartus/sopc_builder/.sopc_builder ]]; then
            sed -i 's,sopc_builder.*,sopc_builder = "/quartus/quartus/sopc_builder";,' \
              $out/quartus/sopc_builder/.sopc_builder
            sed -i 's,sopc_quartus_dir.*,sopc_quartus_dir = "/quartus/quartus";,' \
              $out/quartus/sopc_builder/.sopc_builder
          fi
        '';
    };
  in
  buildFHSEnv {
    inherit pname version executableName;

    extraBwrapArgs = [ "--ro-bind-try /etc/jtagd /etc/jtagd" ];

    extraBuildCommands = ''
      # Ensure software like lmutil can run.
      ln -s /lib64/ld-linux-x86-64.so.2 $out/usr/lib64/ld-lsb-x86-64.so.3

      # Add a reference to the installation from within the FHS environment. In
      # addition to convenience, this allows us to remove references to $out
      # from the FOD quartus installation derivation.
      ln -s ${installation} $out/quartus
    '';

    extraInstallCommands = ''
      progs_to_wrap=(
        "${installation}"/qprogrammer/syscon/bin/*
        "${installation}"/qprogrammer/syscon/bin/**/*
        "${installation}"/qprogrammer/quartus/bin/*
        "${installation}"/quartus/bin/*
        "${installation}"/quartus/sopc_builder/bin/qsys-*
        "${installation}"/questa_fse/bin/*
        "${installation}"/questa_fse/linux_x86_64/lm*
      )

      wrapper=$out/bin/${executableName}
      progs_wrapped=()
      for prog in ''${progs_to_wrap[@]}; do
        if [[ -d "$prog" ]]; then
          continue
        fi
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

      # If we are not quartus-pro-programmer, install desktop files
      if ! [[ -d "${installation}"/qprogrammer ]]; then
        find ${installation} -type f -name quartusii.png -exec install -Dm0644 {} $out/share/icons/hicolor/64x64/apps/quartusii.png \;
        install -Dm0644 ${desktopItem}/share/applications/quartus.desktop $out/share/applications/quartus.desktop
      fi
    '';

    # Hack to make etile executable work. The ldconfig in the FHS env
    # doesn't pick up libncurses.so.5 for some reason. See
    # https://github.com/NixOS/nixpkgs/issues/89769 for more info.
    profile = ''
      export LD_LIBRARY_PATH=${lib.makeLibraryPath [ ncurses5 ]}:$LD_LIBRARY_PATH
    '';

    # Directly passthrough commands from the outer enviroment.
    runScript = "";

    targetPkgs =
      pkgs:
      let
        # TODO(jared): Remove after 26.05 is released.
        xorgDeps =
          if pkgs ? "libice" then
            [
              pkgs.libice
              pkgs.libsm
              pkgs.libx11
              pkgs.libxau
              pkgs.libxcb
              pkgs.libxcb-image
              pkgs.libxcb-keysyms
              pkgs.libxcb-render-util
              pkgs.libxcb-util
              pkgs.libxcb-wm
              pkgs.libxdmcp
              pkgs.libxext
              pkgs.libxft
              pkgs.xcursorgen
            ]
          else
            [
              pkgs.xorg.libICE
              pkgs.xorg.libSM
              pkgs.xorg.libX11
              pkgs.xorg.libXau
              pkgs.xorg.libXdmcp
              pkgs.xorg.libXext
              pkgs.xorg.libXft
              pkgs.xorg.libxcb
              pkgs.xorg.xcbutil
              pkgs.xorg.xcbutilimage
              pkgs.xorg.xcbutilkeysyms
              pkgs.xorg.xcbutilrenderutil
              pkgs.xorg.xcbutilwm
            ];
      in
      [
        pkgs.acl
        pkgs.alsa-lib
        pkgs.attr
        pkgs.bash
        pkgs.bzip2
        pkgs.db4
        pkgs.expat
        pkgs.fontconfig
        pkgs.freetype
        pkgs.glib
        pkgs.gmp
        pkgs.kdePackages.qtbase
        pkgs.kdePackages.qtcharts
        pkgs.kdePackages.qtdeclarative
        pkgs.kdePackages.qtlottie
        pkgs.kdePackages.qtmultimedia
        pkgs.kdePackages.qtquicktimeline
        pkgs.kdePackages.qtremoteobjects
        pkgs.kdePackages.qtscxml
        pkgs.kdePackages.qtsensors
        pkgs.kdePackages.qtspeech
        pkgs.kdePackages.qtvirtualkeyboard
        pkgs.kdePackages.qtwebchannel
        pkgs.kdePackages.qtwebsockets
        pkgs.libGL
        pkgs.libdrm
        pkgs.libxcrypt-legacy
        pkgs.libxkbcommon
        pkgs.ncurses5
        pkgs.python3
        pkgs.readline
        pkgs.sqlite
        pkgs.tcl
        pkgs.tclPackages.tk
        pkgs.udev
        pkgs.xcb-util-cursor
        pkgs.zlib
      ]
      ++ xorgDeps;

    passthru = { inherit installation; };
    meta.platforms = [ "x86_64-linux" ];
  }
)

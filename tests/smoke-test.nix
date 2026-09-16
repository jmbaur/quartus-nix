{
  stdenvNoCC,
  quartus,
}:

# End-to-end smoke test of a full Quartus compile.
stdenvNoCC.mkDerivation {
  name = "${quartus.pname}-${quartus.version}-smoke-test";

  dontUnpack = true;
  nativeBuildInputs = [ quartus ];

  buildPhase = ''
    runHook preBuild

    install -Dm0644 ${./blinky.sv} blinky.sv
    install -Dm0644 ${./blinky.sdc} blinky.sdc
    install -Dm0644 ${./pick.tcl} pick.tcl

    echo "discovering a device to compile for..."
    quartus_sh -t pick.tcl

    family=$(sed -n 1p device.txt)
    device=$(sed -n 2p device.txt)
    echo "compiling for $device ($family)..."

    # Deliberately no location assignments: pin names differ per package, and
    # the fitter is happy to place I/O automatically.
    cat > blinky.qsf <<EOF
    set_global_assignment -name FAMILY "$family"
    set_global_assignment -name DEVICE $device
    set_global_assignment -name TOP_LEVEL_ENTITY blinky
    set_global_assignment -name SYSTEMVERILOG_FILE blinky.sv
    set_global_assignment -name SDC_FILE blinky.sdc
    EOF
    echo 'PROJECT_REVISION = "blinky"' > blinky.qpf

    quartus_sh --flow compile blinky

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm0644 -t $out *.sof *.summary

    runHook postInstall
  '';

  # Smoke test that our setup hook modifications didn't break quartus' ability
  # to ingest the SOF.
  postFixup = ''
    if ! quartus_cpf -c $out/blinky.sof $NIX_BUILD_TOP/roundtrip.rbf; then
      echo "quartus_cpf read failed for SOF $sof" >&2
      exit 1
    fi
  '';

  meta = {
    description = "Compile a tiny design end to end with ${quartus.pname}";
    inherit (quartus.meta) platforms;
  };
}

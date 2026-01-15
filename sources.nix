let
  patchesFor25_3 = [
    {
      url = "https://community.altera.com/t5/s/jgyke29768/attachments/jgyke29768/knowledge-base/10423.10/1/quartus-25.3.1-1.02.zip";
      stripRoot = false;
      hash = "sha256-klnmkbsN/i8G0j//zum2WmrskfcesBbPWubjUOppSjk=";
    }
  ];

  patchesFor25_1 = [
    {
      url = "https://community.altera.com/t5/s/jgyke29768/attachments/jgyke29768/knowledge-base/10423/14/quartus-25.1.1-1.31.zip";
      stripRoot = false;
      hash = "sha256-2c1TGYW5N/wh+ffFPLp/MGm9PFKMOaPfujjiVLXQgWg=";
    }
  ];

  patchesFor24_3 = [
    {
      url = "https://community.altera.com/t5/s/jgyke29768/attachments/jgyke29768/knowledge-base/10423.10/8/quartus-24.3.1-1.29.zip";
      stripRoot = false;
      hash = "sha256-B3Ts5UuLgYNkFthBAB3MdWDO3tR2JnGUKXnXXOWuHqo=";
    }
  ];

  patchesFor24_2 = [
    {
      url = "https://community.altera.com/t5/s/jgyke29768/attachments/jgyke29768/knowledge-base/10423.10/5/quartus-24.2-0.64.zip";
      stripRoot = false;
      hash = "sha256-XrouIEazYVUzM4MomU/wC9b2D1B+tsfVtlQahRQrXlQ=";
    }
  ];
in
{
  quartus-prime-pro = [
    {
      version = "25.1.1";
      url = "https://downloads.intel.com/akdlm/software/acdsinst/25.1.1/125/ib_tar/Quartus-pro-25.1.1.125-linux-complete.tar";
      hash = "sha256-Pl5Mlgcs747P4K0INgEWEDH2LFJpBh6GThipU5E65kE=";
    }
    {
      version = "24.3.1";
      url = "https://downloads.intel.com/akdlm/software/acdsinst/24.3.1/102/ib_tar/Quartus-pro-24.3.1.102-linux-complete.tar";
      hash = "sha256-NLmixbJZshegdg6lhp67lApfU3cmaCbarYpKOmeAK2E=";
    }
    {
      version = "24.2";
      url = "https://downloads.intel.com/akdlm/software/acdsinst/24.2/40/ib_tar/Quartus-pro-24.2.0.40-linux-complete.tar";
      hash = "sha256-vxps9aXwjuSAJh1SfObodkFBC76Bk/Vemz0MfQV7lxg=";
    }
  ];

  quartus-pro-programmer = [
    {
      version = "25.3.1-100";
      url = "https://downloads.intel.com/akdlm/software/acdsinst/25.3.1/100/ib_installers/QuartusProProgrammerSetup-25.3.1.100-linux.run";
      hash = "sha256-cKK+MMBMoogWuQDRqVsRqEcrKtC+ZRJgEqbc5R2lFVI=";
      patches = patchesFor25_3;
    }
    {
      version = "25.1.0-129";
      url = "https://downloads.intel.com/akdlm/software/acdsinst/25.1/129/ib_installers/QuartusProProgrammerSetup-25.1.0.129-linux.run";
      hash = "sha256-BF0vPnCTYoX6/9tP4W3Nlu1/e1TbZuX7qQEy6Y5JiaM=";
      patches = patchesFor25_1;
    }
    {
      version = "24.3.1-102";
      url = "https://downloads.intel.com/akdlm/software/acdsinst/24.3.1/102/ib_installers/QuartusProProgrammerSetup-24.3.1.102-linux.run";
      hash = "sha256-vPaKTrLb3sbW3mvOS7whkWrPlcvCbkvoo76MQXTzXUQ=";
      patches = patchesFor24_3;
    }
    {
      version = "24.2.0-40";
      url = "https://downloads.intel.com/akdlm/software/acdsinst/24.2/40/ib_installers/QuartusProProgrammerSetup-24.2.0.40-linux.run";
      hash = "sha256-XuSs9Yn60V85t7TeBdJPYLMa6rv55Xj8rF6AdGYwbCI=";
      patches = patchesFor24_2;
    }
  ];

  quartus-prime-standard = [
    {
      version = "24.1";
      url = "https://downloads.intel.com/akdlm/software/acdsinst/24.1std/1077/ib_tar/Quartus-24.1std.0.1077-linux-complete.tar";
      hash = "sha256-Rj4qaj0VFGKLYKKwEUwLPtWOJVFlrvnfxhmkt7V1GHo=";
    }
  ];

  quartus-prime-lite = [
    {
      version = "24.1";
      url = "https://downloads.intel.com/akdlm/software/acdsinst/24.1std/1077/ib_tar/Quartus-lite-24.1std.0.1077-linux.tar";
      hash = "sha256-TfTD0GnnAmdsJh4I8DVcMe/99dYJOxOHHmShheWByCM=";
    }
  ];
}

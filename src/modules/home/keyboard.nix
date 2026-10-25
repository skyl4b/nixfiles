{ lib, pkgs, osConfig ? { }, ... }:

let
  layout = "us";
  variant = "colemak_dh";
in
{
  home.keyboard = { inherit layout variant; };

  xdg.autostart = lib.mkIf (osConfig.services.input-remapper.enable or false) {
    enable = lib.mkDefault true;
    entries = [
      "${osConfig.services.input-remapper.package or pkgs.input-remapper}/share/applications/input-remapper-autoload.desktop"
    ];
  };

  # GNOME Wayland reads input sources from the user's dconf database.
  dconf.settings."org/gnome/desktop/input-sources".sources = [
    (lib.hm.gvariant.mkTuple [ "xkb" "${layout}+${variant}" ])
  ];

  # COSMIC has its own per-user XKB configuration; repeat settings use its defaults.
  xdg.configFile."cosmic/com.system76.CosmicComp/v1/xkb_config" =
    lib.mkIf (osConfig.services.desktopManager.cosmic.enable or false) {
      text = ''
        (
          rules: "",
          model: "",
          layout: "${layout}",
          variant: "${variant}",
          options: None,
        )
      '';
    };
}

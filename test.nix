
let
  apps = [ "hypr" "waybar" "foot" "nvim" ];
in
  builtins.listToAttrs (map (app: {
    name = ".config/${app}";
    value = { source = ./config + "/${app}"; force = true; };
  }) apps)

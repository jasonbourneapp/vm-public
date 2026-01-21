{ pkgs, ... }: {
  services.pipewire = {
    enable = true;
    pulse.enable = true;

    extraConfig.pipewire."99-ai-devices" = {
      "context.modules" = [
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "AI_System_Proxy";
            "capture.props" = {
              "node.name" = "AI_System_Proxy";
              "media.class" = "Audio/Sink";
              "audio.position" = [ "FL" "FR" ];
            };
            "playback.props" = {
              "node.name" = "AI_System_Proxy_Output";
              "node.passive" = true;
            };
          };
        }
      ];
    };
  };
}

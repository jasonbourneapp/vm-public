{ pkgs, ... }: {
  services.pipewire = {
    enable = true;
    pulse.enable = true;

    extraConfig.pipewire."99-ai-devices" = {
      "context.modules" = [
        {
          name = "libpipewire-module-loopback";
          args = {
            "node.description" = "AI System Proxy Loopback";
            "capture.props" = {
              "node.name" = "AI_System_Proxy";
              "node.description" = "AI System Proxy"; # Красивое имя для UI
              "media.class" = "Audio/Sink";
              "audio.position" = [ "FL" "FR" ];

              # === Single Source of Truth: Priority Configuration ===
              # Устанавливаем высокий приоритет (>1000), чтобы WirePlumber
              # автоматически выбирал это устройство как Default Sink при загрузке.
              "priority.driver" = 3000;
              "priority.session" = 3000;
            };
            "playback.props" = {
              "node.name" = "AI_System_Proxy_Output";
              "node.passive" = true;
              # stream.dont-remix гарантирует, что мы не будем делать лишнюю
              # обработку при передаче на реальное железо
              "stream.dont-remix" = true;
            };
          };
        }
      ];
    };
  };
}

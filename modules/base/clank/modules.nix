# The modules clank's containers get on top of its own, which the sandboxes
# of agents on anvil (../../../hosts/anvil/agents.nix) run as well.
{clank}: [
  # Magenta modules: gitlab, grafana-logs, kagi and redmine. They route
  # through the credentials-injecting Caddy proxy at clank-proxy:<port>.
  ({...}: {
    imports = [
      "${clank}/magenta/modules/gitlab.nix"
      "${clank}/magenta/modules/grafana-logs.nix"
      "${clank}/magenta/modules/kagi.nix"
      "${clank}/magenta/modules/redmine.nix"
    ];
  })
  ({...}: {
    home-manager.users.root = {
      programs.opencode = {
        # Disable mouse capture so the host terminal's native selection
        # is preserved. The TUI's own copy path (xclip/OSC 52) cannot
        # reach the host clipboard from inside the container anyway.
        cli.mouse = false;
        # Never show the session sidebar; maximize transcript width.
        cli.session.sidebar = "hide";
        settings = {
          "$schema" = "https://opencode.ai/config.json";
          # GreenPT routes through the credentials-injecting proxy like
          # the Magenta tools, so the sandbox only sees the dummy key.
          providers.greenpt.settings = {
            apiKey = "dummy";
            baseURL = "http://clank-proxy:1655/v1";
          };
        };
      };
    };
  })
]

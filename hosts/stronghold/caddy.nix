{ ... }: {
  # HTTP(s)
  networking.firewall.allowedTCPPorts = [ 80 443 8448 ];
  # Needed for QUIC / HTTP/3
  networking.firewall.allowedUDPPorts = [ 443 8448 ];

  services.caddy = {
    enable = true;
    # ACME email account
    email = "caddy@awful.simplelogin.com";

    # TODO: Move this into the traggo file?
    virtualHosts."traggo.awful.engineer" = {
      extraConfig = ''
        reverse_proxy 192.168.100.12:3030
      '';
    };

#    # TODO: Move synapse to this server
    virtualHosts."awful.engineer:8448" = {
      extraConfig = ''
        reverse_proxy /_matrix/* http://192.168.100.13:8008 {
          header_up Host {host}
        }
      '';
    };
    virtualHosts."matrix.awful.engineer" = {
      extraConfig = ''
        reverse_proxy /_matrix/* http://192.168.100.13:8008 {
          header_up Host {host}
        }
        reverse_proxy /_synapse/client/* http://192.168.100.13:8008 {
          header_up Host {host}
        }
      '';
    };
    virtualHosts."matrix.awful.engineer:8448" = {
      extraConfig = ''
        reverse_proxy /_matrix/* http://192.168.100.13:8008 {
          header_up Host {host}
        }
      '';
    };

    virtualHosts."resume.awful.engineer" = {
      extraConfig = ''
        redir https://registry.jsonresume.org/skeen
      '';
    };

    virtualHosts."awful.engineer" = {
      extraConfig = ''
        respond `{"hello": "world"}`
      '';
    };
  };

  environment.persistence."/nix/persist" = {
    hideMounts = true;
    directories = [
      {
        directory = "/var/lib/caddy/";
        user = "caddy";
        group = "caddy";
        mode = "0755";
      }
    ];
  };
}

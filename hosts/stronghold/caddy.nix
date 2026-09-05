{ self, lib, pkgs, ... }:
let
  # RFC 9116 security.txt
  #
  # Expires is stamped at build time from the flake's own last-modified
  # timestamp, so it moves forward on every redeploy instead of needing a
  # manual bump.
  #
  # lastModifiedDate is UTC in YYYYMMDDHHMMSS form. We simply add 1 year to the
  # 1st of the current month snapped to midnight.
  stamp = self.lastModifiedDate;
  at = start: len: builtins.substring start len stamp;
  lastModifiedYear = lib.toInt (at 0 4);
  lastModifiedMonth = at 4 2;
  expires = "${toString (lastModifiedYear + 1)}-${lastModifiedMonth}-01T00:00:00.000Z";

  securityTxt = pkgs.writeTextDir ".well-known/security.txt" ''
    Contact: mailto:security@awful.engineer
    Expires: ${expires}
    Canonical: https://awful.engineer/.well-known/security.txt
    Preferred-Languages: en
  '';
in {
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
        handle /.well-known/security.txt {
          root * ${securityTxt}
          header Content-Type "text/plain; charset=utf-8"
          file_server
        }
        handle {
          respond `{"hello": "world"}`
        }
      '';
    };

    virtualHosts."jellyfin.awful.engineer" = {
      extraConfig = ''
        # Proxy traffic to Granary's wghub IP
        reverse_proxy 192.168.50.2:8096
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

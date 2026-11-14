{
  config,
  lib,
  options,
  pkgs,
  secrets,
  ...
}: let
  labels."app.kubernetes.io/name" = "credentials-proxy";

  # The services the proxy adds credentials for, on the ports clank's proxy
  # has them on (../../modules/base/clank/Caddyfile), as the sandboxes run
  # clank's system (./agents.nix). Each gets where it is and its credentials
  # from a Secret of its name, but Redmine, which runs in the cluster.
  ports = {
    greenpt = 1655;
    kagi = 1394;
    loki = 1932;
    gitlab = 1942;
    redmine = 1974;
  };
  upstreams = {
    greenpt = "https://api.greenpt.ai";
    kagi = "https://mcp.kagi.com";
    loki = "https://logs-prod-us-central1.grafana.net";
    gitlab = "https://git.magenta.dk";
  };

  caddyfile = pkgs.writeText "Caddyfile" ''
    {
    	admin off
    	persist_config off
    	auto_https off
    }

    # GreenPT, the model provider
    :${toString ports.greenpt} {
    	reverse_proxy {$GREENPT_URL} {
    		header_up Authorization "Bearer {$GREENPT_KEY}"
    	}
    }

    # Kagi's MCP server, for web search
    :${toString ports.kagi} {
    	reverse_proxy {$KAGI_URL} {
    		header_up Authorization "Bearer {$KAGI_TOKEN}"
    	}
    }

    # Grafana's Loki, for logs
    :${toString ports.loki} {
    	reverse_proxy {$LOKI_URL} {
    		header_up Authorization "Basic {$LOKI_BASIC}"
    	}
    }

    # GitLab, for its API and git over HTTP
    :${toString ports.gitlab} {
    	reverse_proxy {$GITLAB_URL} {
    		header_up PRIVATE-TOKEN "{$GITLAB_TOKEN}"
    		header_up Authorization "Basic {$GITLAB_BASIC}"
    	}
    }

    # Redmine (./redmine.nix), as AI Bot, whose roles there decide what the
    # agents may do
    :${toString ports.redmine} {
    	reverse_proxy http://redmine.redmine.svc.cluster.local {
    		header_up X-Redmine-API-Key "{$REDMINE_KEY}"
    		header_up -X-Redmine-Switch-User
    	}
    }
  '';

  image = pkgs.dockerTools.buildLayeredImage {
    name = "credentials-proxy";
    contents = [pkgs.dockerTools.caCertificates];
    config = {
      Entrypoint = ["${pkgs.caddy}/bin/caddy" "run" "--adapter" "caddyfile" "--config" "${caddyfile}"];
      # For Caddy's own files, of which it needs none as configured
      Env = ["XDG_CONFIG_HOME=/tmp" "XDG_DATA_HOME=/tmp"];
    };
  };

  fromSecret = secret: name: key: {
    inherit name;
    valueFrom.secretKeyRef = {
      name = secret;
      inherit key;
    };
  };
in {
  # A proxy that adds credentials to the requests of agents, so that they are
  # never in the sandboxes: those of GreenPT, Kagi, Grafana's Loki, GitLab,
  # and of AI Bot in Redmine, the user of the Redmine operator
  # (./redmine-operator.nix). Only sandboxes reach it, as clank-proxy.
  #
  # For now all agents share these credentials; in the long run, each should
  # have its own.
  config = lib.mkMerge [
    {
      services.k3s.images = [image];

      services.k3s.manifests.credentials-proxy.content = [
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata.name = "credentials-proxy";
        }
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "credentials-proxy";
            namespace = "credentials-proxy";
            inherit labels;
          };
          spec = {
            selector.matchLabels = labels;
            template = {
              metadata.labels = labels;
              spec = {
                automountServiceAccountToken = false;
                enableServiceLinks = false;
                containers = [
                  {
                    name = "caddy";
                    image = "${image.imageName}:${image.imageTag}";
                    imagePullPolicy = "Never";
                    env = [
                      (fromSecret "greenpt" "GREENPT_URL" "url")
                      (fromSecret "greenpt" "GREENPT_KEY" "key")
                      (fromSecret "kagi" "KAGI_URL" "url")
                      (fromSecret "kagi" "KAGI_TOKEN" "token")
                      (fromSecret "loki" "LOKI_URL" "url")
                      (fromSecret "loki" "LOKI_BASIC" "basic")
                      (fromSecret "gitlab" "GITLAB_URL" "url")
                      (fromSecret "gitlab" "GITLAB_TOKEN" "token")
                      (fromSecret "gitlab" "GITLAB_BASIC" "basic")
                      (fromSecret "redmine" "REDMINE_KEY" "key")
                    ];
                    ports =
                      lib.mapAttrsToList (name: port: {
                        inherit name;
                        containerPort = port;
                      })
                      ports;
                    readinessProbe.tcpSocket.port = "greenpt";
                    securityContext = {
                      runAsUser = 65534;
                      runAsGroup = 65534;
                      runAsNonRoot = true;
                      allowPrivilegeEscalation = false;
                      readOnlyRootFilesystem = true;
                      capabilities.drop = ["ALL"];
                    };
                    volumeMounts = [
                      {
                        name = "tmp";
                        mountPath = "/tmp";
                      }
                    ];
                  }
                ];
                volumes = [
                  {
                    name = "tmp";
                    emptyDir = {};
                  }
                ];
              };
            };
          };
        }
        {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "clank-proxy";
            namespace = "credentials-proxy";
          };
          spec = {
            selector = labels;
            ports =
              lib.mapAttrsToList (name: port: {
                inherit name port;
                targetPort = name;
              })
              ports;
          };
        }
        # Only for sandboxes, which in turn reach no other credentials
        {
          apiVersion = "networking.k8s.io/v1";
          kind = "NetworkPolicy";
          metadata = {
            name = "credentials-proxy";
            namespace = "credentials-proxy";
          };
          spec = {
            podSelector.matchLabels = labels;
            policyTypes = ["Ingress"];
            ingress = [
              {
                from = [
                  {
                    namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "agents";
                  }
                ];
                ports =
                  lib.mapAttrsToList (_: port: {
                    protocol = "TCP";
                    inherit port;
                  })
                  ports;
              }
            ];
          };
        }
      ];
    }

    # The credentials, from agenix, as the Secrets the proxy reads them from.
    # Only where agenix is (anvil, not ./vm-test.nix).
    (lib.optionalAttrs (options ? age) {
      # The values of clank's Caddyfile (../../modules/base/clank.nix), which
      # are the same credentials, for as long as both exist
      age.secrets.credentials-proxy-env = {
        file = "${secrets}/secrets/clank-caddyfile.env.age";
        mode = "400";
        owner = "root";
        group = "root";
      };
      # AI Bot's API key, which the Redmine operator has too
      age.secrets.credentials-proxy-redmine-key = {
        file = "${secrets}/secrets/redmine-operator-api-key.age";
        mode = "400";
        owner = "root";
        group = "root";
      };

      systemd.services.credentials-proxy-secrets = let
        env = config.age.secrets.credentials-proxy-env;
        redmineKey = config.age.secrets.credentials-proxy-redmine-key;
      in {
        description = "Give the credentials proxy its credentials";
        wantedBy = ["multi-user.target"];
        after = ["k3s.service"];
        wants = ["k3s.service"];
        # Again whenever the secrets change
        restartTriggers = [env.file redmineKey.file];
        path = [config.services.k3s.package];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "10s";
        };
        script = ''
          # A value of clank's Caddyfile
          value() {
            (set -a; . ${env.path}; printf %s "''${!1:-}")
          }
          greenpt=$(value CLANK_GREENPT_TOKEN)
          kagi=$(value CLANK_KAGI_TOKEN)
          loki=$(value CLANK_GRAFANA_TOKEN)
          gitlab_token=$(value CLANK_GITLAB_TOKEN)
          gitlab_basic=$(value CLANK_GITLAB_BASIC)
          for name in greenpt kagi loki gitlab_token gitlab_basic; do
            if [ -z "''${!name}" ]; then
              echo "The value for $name is missing from ${env.file}" >&2
              exit 1
            fi
          done

          until k3s kubectl get namespace credentials-proxy > /dev/null 2>&1; do
            sleep 2
          done
          apply() {
            k3s kubectl -n credentials-proxy create secret generic "$@" --dry-run=client --output=yaml |
              k3s kubectl apply -f -
          }
          applied=$(
            apply greenpt --from-literal=url=${upstreams.greenpt} --from-file=key=<(printf %s "$greenpt")
            apply kagi --from-literal=url=${upstreams.kagi} --from-file=token=<(printf %s "$kagi")
            apply loki --from-literal=url=${upstreams.loki} --from-file=basic=<(printf %s "$loki")
            apply gitlab --from-literal=url=${upstreams.gitlab} \
              --from-file=token=<(printf %s "$gitlab_token") \
              --from-file=basic=<(printf %s "$gitlab_basic")
            apply redmine --from-file=key=<(tr -d '\n' < ${redmineKey.path})
          )
          echo "$applied"
          # The proxy only reads them as it starts
          if [[ $applied == *configured* ]]; then
            k3s kubectl -n credentials-proxy rollout restart deployment credentials-proxy
          fi
        '';
      };
    })
  ];
}

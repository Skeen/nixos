{
  config,
  lib,
  options,
  pkgs,
  secrets,
  ...
}: let
  labels."app.kubernetes.io/name" = "credentials-proxy";

  # Caddy, adding credentials to requests. They come from a Secret per
  # service, along with where the service is: `model-provider`, `redmine`
  # (only its API key, as it runs in the cluster) and `gitlab`.
  caddyfile = pkgs.writeText "Caddyfile" ''
    {
    	admin off
    	persist_config off
    	auto_https off
    }

    # The model provider of the agents (./agents.nix)
    :8080 {
    	reverse_proxy {$MODEL_URL} {
    		header_up Authorization "Bearer {$MODEL_KEY}"
    	}
    }

    # Redmine (./redmine.nix), as AI Bot, whose roles there decide what the
    # agents may do
    :8081 {
    	reverse_proxy http://redmine.redmine.svc.cluster.local {
    		header_up X-Redmine-API-Key "{$REDMINE_KEY}"
    		header_up -X-Redmine-Switch-User
    	}
    }

    # GitLab, for its API and git over HTTP
    :8082 {
    	reverse_proxy {$GITLAB_URL} {
    		header_up PRIVATE-TOKEN "{$GITLAB_TOKEN}"
    		header_up Authorization "Basic {$GITLAB_BASIC}"
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

  # The model provider and GitLab of anvil, whose credentials are secrets (see
  # below)
  modelURL = "https://api.greenpt.ai";
  gitlabURL = "https://git.magenta.dk";

  fromSecret = secret: name: key: {
    inherit name;
    valueFrom.secretKeyRef = {
      name = secret;
      inherit key;
    };
  };
in {
  # A proxy that adds credentials to the requests of agents, so that they are
  # never in the sandboxes, for
  #
  # - their model provider, GreenPT: http://model.credentials-proxy.svc.cluster.local
  # - Redmine, as AI Bot, the user of the Redmine operator
  #   (./redmine-operator.nix): http://redmine.credentials-proxy.svc.cluster.local
  # - GitLab: http://gitlab.credentials-proxy.svc.cluster.local
  #
  # Only sandboxes reach it. For now all agents share these credentials; in
  # the long run, each should have its own.
  config = lib.mkMerge [
    {
      services.k3s.images = [image];

      services.k3s.manifests.credentials-proxy.content =
        [
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
                        (fromSecret "model-provider" "MODEL_URL" "url")
                        (fromSecret "model-provider" "MODEL_KEY" "key")
                        (fromSecret "redmine" "REDMINE_KEY" "key")
                        (fromSecret "gitlab" "GITLAB_URL" "url")
                        (fromSecret "gitlab" "GITLAB_TOKEN" "token")
                        (fromSecret "gitlab" "GITLAB_BASIC" "basic")
                      ];
                      ports = [
                        {
                          name = "model";
                          containerPort = 8080;
                        }
                        {
                          name = "redmine";
                          containerPort = 8081;
                        }
                        {
                          name = "gitlab";
                          containerPort = 8082;
                        }
                      ];
                      readinessProbe.tcpSocket.port = "model";
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
        ]
        # A Service per service it proxies
        ++ map (name: {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            inherit name;
            namespace = "credentials-proxy";
          };
          spec = {
            selector = labels;
            ports = [
              {
                inherit name;
                port = 80;
                targetPort = name;
              }
            ];
          };
        }) ["model" "redmine" "gitlab"]
        ++ [
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
                  ports = [
                    {
                      protocol = "TCP";
                      port = 8080;
                    }
                    {
                      protocol = "TCP";
                      port = 8081;
                    }
                    {
                      protocol = "TCP";
                      port = 8082;
                    }
                  ];
                }
              ];
            };
          }
        ];
    }

    # The credentials, from agenix, as the Secrets the proxy reads them from.
    # Only where agenix is (anvil, not ./vm-test.nix).
    (lib.optionalAttrs (options ? age) {
      # The GreenPT and GitLab credentials clank's proxy gets
      # (../../modules/base/clank.nix), among the other values of its
      # Caddyfile, for as long as both exist
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
          # A value of the Caddyfile of clank
          value() {
            (set -a; . ${env.path}; printf %s "''${!1:-}")
          }
          greenpt=$(value CLANK_GREENPT_TOKEN)
          gitlab_token=$(value CLANK_GITLAB_TOKEN)
          gitlab_basic=$(value CLANK_GITLAB_BASIC)
          for name in greenpt gitlab_token gitlab_basic; do
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
            apply model-provider --from-literal=url=${modelURL} --from-file=key=<(printf %s "$greenpt")
            apply redmine --from-file=key=<(tr -d '\n' < ${redmineKey.path})
            apply gitlab --from-literal=url=${gitlabURL} \
              --from-file=token=<(printf %s "$gitlab_token") \
              --from-file=basic=<(printf %s "$gitlab_basic")
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

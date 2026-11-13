{
  config,
  lib,
  options,
  pkgs,
  secrets,
  ...
}: let
  operatorLabels."app.kubernetes.io/name" = "redmine-operator";

  # The operator (./redmine-operator/operator.py), built into an image which is
  # loaded into the cluster directly, rather than pulled from a registry.
  operatorImage = let
    python = pkgs.python3.withPackages (ps: [ps.aiohttp ps.kopf ps.kubernetes-asyncio]);
  in
    pkgs.dockerTools.buildLayeredImage {
      name = "redmine-operator";
      config = {
        Entrypoint = [
          "${python}/bin/kopf"
          "run"
          "--standalone"
          "--liveness=http://0.0.0.0:8080/healthz"
          "${./redmine-operator/operator.py}"
        ];
        # kopf names itself after the user, and the image has no users
        Env = ["USER=redmine-operator"];
      };
    };
in {
  # A Kubernetes operator, built with kopf, which has agents (./agents.nix)
  # work on the tickets of Redmine (./redmine.nix). Its configuration is a
  # custom resource, a RedmineProject, naming a project in Redmine and the warm
  # pool to claim the agents' sandboxes from. Every open ticket in the project
  # assigned to the operator's Redmine user, `ai`, gets a sandbox named after
  # it, such as redmine-42. The operator hands the ticket to the agent in it,
  # posts the agent's replies on the ticket as notes, and hands it the notes
  # others add. Closing the ticket, or assigning it to someone else, deletes
  # the sandbox.
  #
  #   sudo k3s kubectl -n agents get redmineprojects,sandboxclaims
  #
  # The operator acts in Redmine as `ai`, with its API key from agenix.
  config = lib.mkMerge [
    {
      services.k3s.images = [operatorImage];

      services.k3s.manifests.redmine-operator.content = [
        {
          apiVersion = "apiextensions.k8s.io/v1";
          kind = "CustomResourceDefinition";
          metadata.name = "redmineprojects.agents.internal";
          spec = {
            group = "agents.internal";
            scope = "Namespaced";
            names = {
              kind = "RedmineProject";
              plural = "redmineprojects";
              singular = "redmineproject";
            };
            versions = [
              {
                name = "v1alpha1";
                served = true;
                storage = true;
                subresources.status = {};
                additionalPrinterColumns = [
                  {
                    name = "Project";
                    type = "string";
                    jsonPath = ".spec.project";
                  }
                  {
                    name = "Warm pool";
                    type = "string";
                    jsonPath = ".spec.warmPool";
                  }
                  {
                    name = "Tickets";
                    type = "string";
                    jsonPath = ".status.tickets";
                  }
                ];
                schema.openAPIV3Schema = {
                  type = "object";
                  properties = {
                    spec = {
                      type = "object";
                      required = ["project" "warmPool"];
                      properties = {
                        project = {
                          type = "string";
                          description = "Identifier of the project in Redmine whose tickets get sandboxes.";
                        };
                        warmPool = {
                          type = "string";
                          description = "SandboxWarmPool in the same namespace to claim the sandboxes from.";
                        };
                        inProgressStatus = {
                          type = "string";
                          description = "Status to move tickets to as their agent starts working on them, if any.";
                        };
                        feedbackStatus = {
                          type = "string";
                          description = "Status to move tickets to as their agent replies, if any.";
                        };
                      };
                    };
                    status = {
                      type = "object";
                      x-kubernetes-preserve-unknown-fields = true;
                    };
                  };
                };
              }
            ];
          };
        }
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata.name = "redmine-operator";
        }
        # The namespace it serves, where its RedmineProjects are, and the
        # sandboxes it claims for them (./agents.nix)
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata.name = "agents";
        }
        {
          apiVersion = "v1";
          kind = "ServiceAccount";
          metadata = {
            name = "redmine-operator";
            namespace = "redmine-operator";
          };
        }
        # What the operator may do in the namespace it serves
        {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "Role";
          metadata = {
            name = "redmine-operator";
            namespace = "agents";
          };
          rules = [
            {
              apiGroups = ["agents.internal"];
              resources = ["redmineprojects"];
              verbs = ["get" "list" "watch" "patch"];
            }
            {
              apiGroups = ["agents.internal"];
              resources = ["redmineprojects/status"];
              verbs = ["get" "patch"];
            }
            {
              apiGroups = ["extensions.agents.x-k8s.io"];
              resources = ["sandboxclaims"];
              verbs = ["get" "list" "watch" "create" "delete"];
            }
            # The password of the agents' servers, which the operator makes up
            {
              apiGroups = [""];
              resources = ["secrets"];
              resourceNames = ["agent-server"];
              verbs = ["get"];
            }
            {
              apiGroups = [""];
              resources = ["secrets"];
              verbs = ["create"];
            }
            {
              apiGroups = ["" "events.k8s.io"];
              resources = ["events"];
              verbs = ["create"];
            }
          ];
        }
        {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "RoleBinding";
          metadata = {
            name = "redmine-operator";
            namespace = "agents";
          };
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "Role";
            name = "redmine-operator";
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = "redmine-operator";
              namespace = "redmine-operator";
            }
          ];
        }
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "redmine-operator";
            namespace = "redmine-operator";
            labels = operatorLabels;
          };
          spec = {
            selector.matchLabels = operatorLabels;
            # Never two operators at once
            strategy.type = "Recreate";
            template = {
              metadata.labels = operatorLabels;
              spec = {
                serviceAccountName = "redmine-operator";
                containers = [
                  {
                    name = "operator";
                    image = "${operatorImage.imageName}:${operatorImage.imageTag}";
                    imagePullPolicy = "Never";
                    args = ["--namespace=agents"];
                    env = [
                      {
                        name = "REDMINE_URL";
                        value = "http://redmine.redmine.svc.cluster.local";
                      }
                      {
                        name = "REDMINE_API_KEY";
                        valueFrom.secretKeyRef = {
                          name = "redmine-api-key";
                          key = "key";
                        };
                      }
                    ];
                    livenessProbe.httpGet = {
                      path = "/healthz";
                      port = 8080;
                    };
                    securityContext = {
                      runAsUser = 65534;
                      runAsGroup = 65534;
                      runAsNonRoot = true;
                      allowPrivilegeEscalation = false;
                      readOnlyRootFilesystem = true;
                      capabilities.drop = ["ALL"];
                    };
                  }
                ];
              };
            };
          };
        }
        {
          apiVersion = "agents.internal/v1alpha1";
          kind = "RedmineProject";
          metadata = {
            name = "ai";
            namespace = "agents";
          };
          spec = {
            project = "ai";
            warmPool = "agent";
            inProgressStatus = "In Progress";
            feedbackStatus = "Feedback";
          };
        }
      ];
    }

    # The API key of `ai`, from agenix, as the Secret the operator reads it
    # from. Only where agenix is (anvil, not ./vm-test.nix).
    (lib.optionalAttrs (options ? age) {
      age.secrets.redmine-operator-api-key = {
        file = "${secrets}/secrets/redmine-operator-api-key.age";
        mode = "400";
        owner = "root";
        group = "root";
      };

      systemd.services.redmine-operator-api-key = {
        description = "Give the Redmine operator its API key";
        wantedBy = ["multi-user.target"];
        after = ["k3s.service"];
        wants = ["k3s.service"];
        # Again whenever the secret changes
        restartTriggers = [config.age.secrets.redmine-operator-api-key.file];
        path = [config.services.k3s.package];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "10s";
        };
        script = ''
          until k3s kubectl get namespace redmine-operator > /dev/null 2>&1; do
            sleep 2
          done
          applied=$(
            k3s kubectl -n redmine-operator create secret generic redmine-api-key \
              --from-file=key=${config.age.secrets.redmine-operator-api-key.path} \
              --dry-run=client --output=yaml |
              k3s kubectl apply -f -
          )
          echo "$applied"
          # The operator only reads it as it starts
          if [[ $applied == *configured ]]; then
            k3s kubectl -n redmine-operator rollout restart deployment redmine-operator
          fi
        '';
      };
    })
  ];
}

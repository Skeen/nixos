# The clank-inspired sandbox itself:
#
# 1. An OCI image built from clank's NixOS container configuration (root tmpfs,
#    fish, opencode with the Magenta modules - gitlab, grafana-logs, kagi - and
#    the berget-auth plugin), minus everything that depends on clank's CWD
#    forwarding (/clank/cwd, /clank/command, getty autologin) and podman.
# 2. Kubernetes manifests: the namespace, the proxy-credentials Secret (values
#    rendered from the agenix-managed clank-caddyfile.env into a Kubernetes
#    Secret), the Caddy credentials proxy packaged as an image, a
#    SandboxTemplate with the sandbox + proxy sidecar, a pre-warmed pool and a
#    claim to spawn Sandboxes from it.
#
# Everything except the Secret's values is declarative; the values are injected
# at runtime by a systemd oneshot that reads the agenix secret and creates the
# Kubernetes Secret via kubectl.
{
  config,
  lib,
  pkgs,
  secrets,
  clank,
  nixpkgs-unstable,
  home-manager-unstable,
  ...
}: let
  pkgsUnstable = nixpkgs-unstable.legacyPackages.x86_64-linux;

  # systemd services inside the sandbox don't get the home-manager profile on
  # PATH, so call opencode by store path (the same package HM installs).
  opencodePackage = pkgsUnstable.opencode;

  # --- Sandbox image -------------------------------------------------------
  # A NixOS system built from clank's container modules, for running inside a
  # Kata MicroVM as a pod.
  sandboxSystem = nixpkgs-unstable.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      # clank's container modules expect the home-manager module via
      # inputs.home-manager; give them ours (unstable, same nixpkgs).
      inputs.home-manager = home-manager-unstable;
    };
    modules = [
      "${clank}/container"

      # Adjust clank for life in a Kubernetes pod:
      {
        disabledModules = [
          # Claude Code: unfree + bind-mounts /root/.claude (host path). The
          # request was opencode + extra modules only.
          "${clank}/container/claude.nix"
          # Podman-in-podman is pointless under Kata: there is no daemon to
          # share images with on the node (self-contained image).
          "${clank}/container/podman.nix"
          # clank's getty/CWD-forwarding shell logic (fish loginShellInit cd's
          # into /clank/cwd and execs /clank/command) is exactly what we must
          # NOT do here. Drop shell.nix entirely and provide our own.
          "${clank}/container/shell.nix"
        ];

        # No host bind mounts inside the image: root is the overlay fs.
        fileSystems = lib.mkForce {};

        # The Kata VM init runs systemd as PID 1 from the image's /init; the
        # clank container config expects systemd, which works, but nothing
        # should try to autologin on a getty (there is no console).
        services.getty.autologinUser = lib.mkForce null;

        # Extra modules: Magenta (gitlab, grafana-logs, kagi) + berget auth,
        # matching modules/base/clank.nix on the dev hosts.
        imports = let
          # https://github.com/berget-ai/opencode-berget-auth
          # Adds `/connect` for Berget auth. Referenced by store path so
          # OpenCode loads it locally instead of fetching from npm.
          berget-auth = pkgsUnstable.fetchzip {
            name = "opencode-berget-auth-1.0.24";
            url = "https://registry.npmjs.org/@bergetai/opencode-auth/-/opencode-auth-1.0.24.tgz";
            hash = "sha256-4wt5VA5RiqWWW7030apXEoHQNWIj+aCXUXDfBVozf98=";
          };
        in [
          "${clank}/magenta/modules/gitlab.nix"
          "${clank}/magenta/modules/grafana-logs.nix"
          "${clank}/magenta/modules/kagi.nix"
          (
            {pkgs, ...}: {
              home-manager.users.root = {
                programs.opencode = {
                  settings = {
                    "$schema" = "https://opencode.ai/config.json";
                    plugin = ["${berget-auth}"];
                    # BergetAI can be slow; give requests plenty of headroom
                    # (same rationale as modules/base/clank.nix).
                    provider.berget.options = {
                      timeout = 1800000;
                      headerTimeout = 120000;
                      chunkTimeout = 300000;
                    };
                  };
                };
              };

              # Keep the sandbox alive: a tmux session running opencode, so
              # `kubectl exec` (or an agent harness) can interact with it.
              # This replaces clank's getty approach without CWD forwarding.
              environment.systemPackages = [pkgs.tmux];
              systemd.services.sandbox-tmux = {
                description = "Start the coding-agent tmux session";
                wantedBy = ["multi-user.target"];
                after = ["network.target"];
                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                };
                script = with pkgsUnstable; ''
                  ${tmux}/bin/tmux kill-server 2>/dev/null || true
                  ${tmux}/bin/tmux new-session -d -s clank
                  ${tmux}/bin/tmux send-keys -t clank \
                    "cd /workspace; exec ${opencodePackage}/bin/opencode" Enter
                '';
              };
            }
          )
        ];
      }
    ];
  };

  sandboxToplevel = sandboxSystem.config.system.build.toplevel;

  # Self-contained OCI image: the whole NixOS closure lives inside the image,
  # so the Kata MicroVM needs no access to the host's /nix/store.
  sandboxImage = pkgsUnstable.dockerTools.buildImage {
    name = "clank-sandbox";
    tag = "latest";
    copyToRoot = pkgsUnstable.buildEnv {
      name = "clank-sandbox-image";
      paths = [sandboxToplevel];
    };
    config = {
      # NixOS stage-2 init: runs the activation script, then execs systemd.
      Entrypoint = ["${sandboxToplevel}/init"];
      Env = [
        # NixOS init probes for container detection
        "container=docker"
        "PATH=/run/current-system/sw/bin:/run/current-system/systemd/bin"
      ];
    };
  };

  # --- Credentials proxy image --------------------------------------------
  caddyProxyImage = pkgs.dockerTools.buildImage {
    name = "clank-proxy";
    tag = "latest";
    copyToRoot = pkgs.buildEnv {
      name = "clank-proxy-root";
      pathsToLink = ["/bin"];
      paths = [pkgs.caddy];
    };
    config = {
      Entrypoint = ["/bin/caddy"];
      # The Caddyfile is supplied via the clank-caddyfile ConfigMap, and the
      # {$VAR} token values via the clank-proxy-credentials Secret.
      Cmd = ["run" "--config" "/etc/clank/Caddyfile"];
    };
  };

  # Public Caddyfile template: identical shape to modules/base/clank/Caddyfile,
  # but the {$VAR} tokens are substituted by Caddy itself from the environment
  # variables provided by the k8s Secret (clank does not pass env into the
  # proxy - hence the Secret).
  caddyfile = ''
    # Clank credentials proxy. The {$VAR} tokens are substituted by Caddy from
    # environment variables supplied from the clank-proxy-credentials Secret.
    # MCP Servers
    :1394 {
    	reverse_proxy https://mcp.kagi.com {
    		header_up Authorization "Bearer {$CLANK_KAGI_TOKEN}"
    	}
    }

    # Agent Skills
    :1932 {
    	reverse_proxy https://logs-prod-us-central1.grafana.net {
    		header_up Authorization "Basic {$CLANK_GRAFANA_TOKEN}"
    	}
    }

    :1942 {
    	reverse_proxy https://git.magenta.dk {
    		# https://git.magenta.dk/-/user_settings/personal_access_tokens (api, write_repository)
    		header_up PRIVATE-TOKEN "{$CLANK_GITLAB_TOKEN}"
    		# printf 'clank:<token>' | base64 --wrap=0
    		header_up Authorization "Basic {$CLANK_GITLAB_BASIC}"
    	}
    }
  '';

  # --- Kubernetes objects ---------------------------------------------------
  namespace = {
    apiVersion = "v1";
    kind = "Namespace";
    metadata.name = "sandboxes";
  };

  caddyfileConfigMap = {
    apiVersion = "v1";
    kind = "ConfigMap";
    metadata = {
      name = "clank-caddyfile";
      namespace = "sandboxes";
    };
    data."Caddyfile" = caddyfile;
  };

  sandboxTemplate = {
    apiVersion = "extensions.agents.x-k8s.io/v1beta1";
    kind = "SandboxTemplate";
    metadata = {
      name = "clank";
      namespace = "sandboxes";
    };
    spec.podTemplate.spec = {
      # Kata (QEMU MicroVM) runtime, as registered in agent-sandbox.nix.
      runtimeClassName = "kata";
      # Sandboxes never talk to the apiserver.
      automountServiceAccountToken = false;
      restartPolicy = "Always";
      terminationGracePeriodSeconds = 30;
      # The Magenta modules (git insteadOf, Kagi MCP, Loki) and the glab CLI
      # hard-code the hostname `clank-proxy`, which in local clank is a podman
      # network alias. In a pod, containers share the network namespace, so
      # the proxy is reachable on localhost - alias the name to 127.0.0.1.
      hostAliases = [
        {
          ip = "127.0.0.1";
          hostnames = ["clank-proxy"];
        }
      ];
      containers = [
        {
          name = "clank";
          image = "${sandboxImage.imageName}:${sandboxImage.imageTag}";
          imagePullPolicy = "Never"; # seeded into containerd on the node
          # Run systemd (via stage-2 init) inside the MicroVM. privileged is
          # required by systemd inside the Kata guest.
          command = ["${sandboxToplevel}/init"];
          securityContext.privileged = true;
          env = [
            {
              # NixOS init probes for container detection
              name = "container";
              value = "docker";
            }
            {
              # Point the gitlab module's rewrites at the in-pod proxy
              name = "KUBERNETES_SANDBOX";
              value = "1";
            }
          ];
          resources = {
            requests = {
              cpu = "1";
              memory = "2Gi";
            };
            limits = {
              cpu = "4";
              memory = "8Gi";
            };
          };
          volumeMounts = [
            {
              # The sandbox works in /workspace (created by tmpfiles below).
              name = "workspace";
              mountPath = "/workspace";
            }
            {
              name = "clank-caddyfile";
              mountPath = "/etc/clank";
              readOnly = true;
            }
          ];
        }
        # The per-sandbox Caddy credentials-proxy sidecar, as in clank, but
        # its tokens come from a k8s Secret instead of a rendered Caddyfile.
        {
          name = "clank-proxy";
          image = "${caddyProxyImage.imageName}:${caddyProxyImage.imageTag}";
          imagePullPolicy = "Never";
          envFrom = [
            {
              secretRef = {
                name = "clank-proxy-credentials";
              };
            }
          ];
          resources = {
            requests = {
              cpu = "50m";
              memory = "64Mi";
            };
            limits = {
              cpu = "1";
              memory = "256Mi";
            };
          };
          volumeMounts = [
            {
              name = "clank-caddyfile";
              mountPath = "/etc/clank";
              readOnly = true;
            }
          ];
        }
      ];
      volumes = [
        {
          name = "workspace";
          emptyDir = {};
        }
        {
          name = "clank-caddyfile";
          configMap = {
            name = "clank-caddyfile";
          };
        }
      ];
    };
  };

  warmPool = {
    apiVersion = "extensions.agents.x-k8s.io/v1beta1";
    kind = "SandboxWarmPool";
    metadata = {
      name = "clank";
      namespace = "sandboxes";
    };
    spec = {
      # One pre-warmed Kata VM to make claims near-instant. Cheap enough on a
      # dedicated CCX, and the first `gk claim` shouldn't wait for a boot.
      replicas = 1;
      sandboxTemplateRef.name = "clank";
      updateStrategy.type = "Recreate";
    };
  };

  sandboxClaim = {
    apiVersion = "extensions.agents.x-k8s.io/v1beta1";
    kind = "SandboxClaim";
    metadata = {
      name = "clank";
      namespace = "sandboxes";
    };
    spec = {
      warmPoolRef.name = "clank";
      lifecycle.shutdownPolicy = "Delete";
    };
  };
in {
  # --- The proxy credentials Secret, from agenix --------------------------
  # The tokens live encrypted in the nixos-secret repo (clank-caddyfile.env.age
  # - same file stronghold's users decrypt for local clank); golem decrypts it
  # with its own host key and pushes the values into a Kubernetes Secret. This
  # keeps the credentials out of the nix store and out of git.
  age.secrets.clank-caddyfile-env = {
    file = "${secrets}/secrets/clank-caddyfile.env.age";
    mode = "440";
    owner = "root";
    group = "kubernetes";
  };

  systemd.services.clank-proxy-secret = {
    description = "Sync clank proxy credentials into the Kubernetes Secret";
    wantedBy = ["multi-user.target"];
    after = ["kube-apiserver.service"];
    requires = ["kube-apiserver.service"];
    path = [pkgs.kubernetes];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -euo pipefail
      export KUBECONFIG=/etc/${config.services.kubernetes.pki.etcClusterAdminKubeconfig}

      echo "Waiting for the apiserver to become ready..."
      for i in $(seq 1 120); do
        if kubectl get --raw=/readyz >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # The namespace comes from the addon manager (Reconcile); wait for it.
      for i in $(seq 1 120); do
        if kubectl get namespace sandboxes >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # create/update the Secret from the agenix-rendered env file
      kubectl -n sandboxes create secret generic clank-proxy-credentials \
        --from-env-file=${config.age.secrets.clank-caddyfile-env.path} \
        --dry-run=client -o yaml | kubectl apply -f -
    '';
  };

  # The declarative objects, applied through the addon manager (Reconcile):
  services.kubernetes.addonManager.addons = {
    sandboxes-namespace = namespace;
    clank-caddyfile = caddyfileConfigMap;
    clank-sandboxtemplate = sandboxTemplate;
    clank-sandboxwarmpool = warmPool;
    clank-sandboxclaim = sandboxClaim;
  };

  # Seed the sandbox + proxy images into containerd before kubelet starts
  # (same mechanism coredns uses). kubelet's preStart `ctr -n k8s.io image
  # import` handles the docker-archive tarballs that dockerTools emits.
  services.kubernetes.kubelet.seedDockerImages = [
    sandboxImage
    caddyProxyImage
  ];
}

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

        # "*" = password login impossible, but the account is NOT locked.
        # A locked root ("!" hash) makes sshd refuse even pubkey auth.
        users.users.root.hashedPassword = lib.mkForce "*";

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
              # a shell (kubectl exec / SSH, see sandbox-sshd) can interact
              # with it. This replaces clank's getty approach without CWD
              # forwarding.
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

              # SSH into the sandbox: kubectl exec cannot attach to a
              # systemd-as-PID1 container under kata (EBUSY,
              # kata-containers#10733), so sshd is the reliable shell path.
              # The public keys come from the clank-sandbox-keys Secret,
              # mounted read-only at /etc/sandbox-keys; read them straight
              # from the mount so there is no copy step that could race
              # sshd. (Not /run: the container's own systemd mounts a tmpfs
              # over /run at boot and would hide the volume.)
              services.openssh = {
                enable = true;
                # Key-only: sandboxes are reached over the pod network
                # through kubectl port-forward or the flannel network.
                settings.PasswordAuthentication = false;
                settings.KbdInteractiveAuthentication = false;
                settings.PermitRootLogin = "prohibit-password";
                settings.AuthorizedKeysFile = "/etc/sandbox-keys/authorized_keys";
                # The k8s Secret volume dir is 1777 (tmpfs): sshd's default
                # StrictModes would refuse to read keys from a world-writable
                # path, so relax it inside the sandbox.
                settings.StrictModes = false;
                # No PAM: the container has no local passwords (key-only) and
                # sandbox PAM account rules deny root entirely
                # ("Access denied for user root by PAM account configuration").
                settings.UsePAM = false;
                # No host keys to persist across restarts of a stateless
                # sandbox; generate at boot instead.
                startWhenNeeded = false;
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
  # All objects carry the addon-manager mode label: kube-addon-manager only
  # reconciles objects matching its `addonmanager.kubernetes.io/mode`
  # label selector, so titles without the label would be ignored.
  namespace = {
    apiVersion = "v1";
    kind = "Namespace";
    metadata = {
      name = "sandboxes";
      labels."addonmanager.kubernetes.io/mode" = "Reconcile";
    };
  };

  caddyfileConfigMap = {
    apiVersion = "v1";
    kind = "ConfigMap";
    metadata = {
      name = "clank-caddyfile";
      namespace = "sandboxes";
      labels."addonmanager.kubernetes.io/mode" = "Reconcile";
    };
    data."Caddyfile" = caddyfile;
  };

  sandboxTemplate = {
    apiVersion = "extensions.agents.x-k8s.io/v1beta1";
    kind = "SandboxTemplate";
    metadata = {
      name = "clank";
      namespace = "sandboxes";
      labels."addonmanager.kubernetes.io/mode" = "Reconcile";
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
            {
              # Public SSH keys allowed into the sandbox (clank-sandbox-keys
              # Secret). /etc/sandbox-keys, not /run/...: the container's
              # systemd mounts a tmpfs over /run at boot.
              name = "sandbox-keys";
              mountPath = "/etc/sandbox-keys";
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
        {
          name = "sandbox-keys";
          secret = {
            secretName = "clank-sandbox-keys";
            # Optional: without the Secret (fresh VMs before the sync
            # oneshot ran) the pod still starts; sshd just stays keyless
            # (the mount dir is empty and the oneshot fails safely).
            optional = true;
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
      labels."addonmanager.kubernetes.io/mode" = "Reconcile";
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
      labels."addonmanager.kubernetes.io/mode" = "Reconcile";
    };
    spec = {
      warmPoolRef.name = "clank";
      lifecycle.shutdownPolicy = "Delete";
    };
  };

  # SSH into the claimed sandbox: a NodePort Service maps golem:32222 to the
  # sandbox's sshd (port 22). kube-proxy does the DNAT to the pod IP directly,
  # which - unlike kubectl exec (broken for kata+systemd containers,
  # kata-containers#10733) and kubectl port-forward (dials 127.0.0.1 in the
  # host-side CNI netns, where nothing listens under kata) - works with any
  # stock ssh client:
  #
  #   ssh root@golem.example.dk -p 32222        # from anywhere
  #   ssh clank-ssh.sandboxes.svc.cluster.local # from inside the cluster
  #   ssh -J root@golem root@clank-ssh.sandboxes.svc.cluster.local
  #
  # The selector pins the claimed Sandbox's pod via the controller-set
  # sandbox-name-hash label (hash of the sandbox name "clank", stable across
  # boots and claim recreations), so remote shells always land in the
  # working sandbox and never in an idle warm-pool pod.
  sshService = {
    apiVersion = "v1";
    kind = "Service";
    metadata = {
      name = "clank-ssh";
      namespace = "sandboxes";
      labels."addonmanager.kubernetes.io/mode" = "Reconcile";
    };
    spec = {
      type = "NodePort";
      selector."agents.x-k8s.io/sandbox-name-hash" = "c335e302";
      ports = [
        {
          name = "ssh";
          port = 22;
          targetPort = 22;
          nodePort = 32222;
          protocol = "TCP";
        }
      ];
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

  # --- The sandbox SSH keys, from agenix -----------------------------------
  # Public keys minted into the sandboxes' /root/.ssh/authorized_keys.
  # Encrypted age file holds the public half (no harm in leaking, but keeps
  # the repo tidy); blank fallback for fresh VMs without the age identity -
  # SSH then simply has no authorized keys.
  age.secrets.clank-sandbox-keys = {
    file = "${secrets}/secrets/clank-sandbox-keys.pub.age";
    mode = "440";
    owner = "root";
    group = "kubernetes";
  };

  systemd.services.clank-proxy-secret = {
    description = "Sync clank proxy credentials into the Kubernetes Secret";
    wantedBy = ["multi-user.target"];
    after = ["kube-apiserver.service"];
    # wants (not requires): kube-apiserver crash-loops during early cert
    # bootstrap; requires would propagate each stop and TERM our oneshots
    # until systemd rates-limits them into permanent failure.
    wants = ["kube-apiserver.service"];
    path = [pkgs.kubernetes];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "10min";
      # Boot-time race: the apiserver (and cfssl) can still be starting; a
      # TERM during the wait must not exhaust systemd's default retries.
      Restart = "on-failure";
      RestartSec = "15s";
    };
    script = ''
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

      # create/update the Secret from the agenix-rendered env file. agenix
      # cannot decrypt without the host's private key (fresh installs, CI
      # VMs): fall back to blank values rather than fail the boot - Caddy
      # simply proxies without credentials until the next rebuild switch on
      # the real host, where decryption succeeds.
      envFile=${config.age.secrets.clank-caddyfile-env.path}
      if ! [ -r "$envFile" ]; then
        echo "WARNING: ${config.age.secrets.clank-caddyfile-env.path} not readable (age identity missing?), creating the Secret with blank values"
        envFile=${
        pkgs.writeText "clank-proxy-credentials.empty" ""
      }
      fi

      kubectl -n sandboxes create secret generic clank-proxy-credentials \
        --from-env-file="$envFile" \
        --dry-run=client -o yaml | kubectl apply -f -
    '';
  };

  # Sync the sandbox SSH public keys into a Kubernetes Secret that the
  # SandboxTemplate mounts into every sandbox (see sandbox-sshd-keys inside
  # the image). agenix fallback, same as above.
  systemd.services.clank-sandbox-keys = {
    description = "Sync sandbox SSH public keys into the Kubernetes Secret";
    wantedBy = ["multi-user.target"];
    after = ["kube-apiserver.service"];
    # wants (not requires): kube-apiserver crash-loops during early cert
    # bootstrap; requires would propagate each stop and TERM our oneshots
    # until systemd rates-limits them into permanent failure.
    wants = ["kube-apiserver.service"];
    path = [pkgs.kubernetes];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "10min";
      # Boot-time race: the apiserver (and cfssl) can still be starting; a
      # TERM during the wait must not exhaust systemd's default retries.
      Restart = "on-failure";
      RestartSec = "15s";
    };
    script = ''
      export KUBECONFIG=/etc/${config.services.kubernetes.pki.etcClusterAdminKubeconfig}

      echo "Waiting for the apiserver to become ready..."
      for i in $(seq 1 120); do
        if kubectl get --raw=/readyz >/dev/null 2>&1; then
          break
        fi
        sleep 2
      done

      # Prefer the locally generated key (clank-sandbox-ssh-key service); the
      # age file serves fresh installs where the local key is not there yet.
      keysFile=/etc/clank/golem-ed25519.pub
      if ! [ -r "$keysFile" ] || ! [ -s "$keysFile" ]; then
        keysFile=${config.age.secrets.clank-sandbox-keys.path}
      fi
      if ! [ -r "$keysFile" ] || ! [ -s "$keysFile" ]; then
        echo "WARNING: no sandbox SSH keys (neither /etc/clank/golem-ed25519.pub nor $keysFile), creating the Secret with no keys"
        keysFile=${pkgs.writeText "clank-sandbox-keys.empty" ""}
      fi

      kubectl -n sandboxes create secret generic clank-sandbox-keys \
        --from-file=authorized_keys="$keysFile" \
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
    clank-ssh = sshService;
  };

  # The SSH keypair golem uses for sandboxes: the private half is generated
  # once on the host (persisted via impermanence like the ssh host key), the
  # public half is pushed into the clank-sandbox-keys Secret by the sync
  # oneshot. The age file in the secrets repo serves fresh installs and
  # other operators (who usually want their own key in there anyway).
  systemd.services.clank-sandbox-ssh-key = {
    description = "Ensure the golem-to-sandbox SSH keypair exists";
    wantedBy = ["multi-user.target"];
    before = ["clank-sandbox-keys.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      d=/etc/clank
      mkdir -p "$d"
      if ! [ -s "$d/golem-ed25519" ]; then
        ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" -f "$d/golem-ed25519" -C golem-sandboxes
      fi
      chmod 600 "$d/golem-ed25519"
    '';
  };

  # RBAC for the addon manager: NixOS only grants it rights inside
  # kube-system (+ cluster-wide list). Our addons need to create the
  # `sandboxes` namespace and manage agent-sandbox resources in it.
  # bootstrapAddons are applied with cluster-admin rights at pki start.
  services.kubernetes.addonManager.bootstrapAddons = {
    sandboxes-addon-manager-cr = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRole";
      metadata.name = "kube-addon-manager-sandboxes";
      rules = [
        {
          apiGroups = [""];
          resources = ["namespaces"];
          verbs = ["get" "list" "watch" "create" "update" "patch"];
        }
        {
          apiGroups = ["extensions.agents.x-k8s.io" "agents.x-k8s.io"];
          resources = ["*"];
          verbs = ["*"];
        }
        {
          # Keep core resources in their own rule: merging "" with named
          # groups makes kubectl/authz resolve them to the named group only.
          apiGroups = [""];
          resources = ["namespaces" "configmaps" "secrets" "pods" "services" "events" "persistentvolumeclaims"];
          verbs = ["get" "list" "watch" "create" "update" "patch" "delete"];
        }
        {
          apiGroups = ["apps" "batch"];
          resources = ["deployments" "pods" "services" "configmaps" "secrets" "events" "persistentvolumeclaims"];
          verbs = ["get" "list" "watch" "create" "update" "patch" "delete"];
        }
      ];
    };
    sandboxes-addon-manager-crb = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRoleBinding";
      metadata.name = "kube-addon-manager-sandboxes";
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "kube-addon-manager-sandboxes";
      };
      subjects = [
        {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "User";
          name = "system:kube-addon-manager";
        }
      ];
    };
  };

  # Seed the sandbox + proxy images into containerd before kubelet starts
  # (same mechanism coredns uses). kubelet's preStart `ctr -n k8s.io image
  # import` handles the docker-archive tarballs that dockerTools emits.
  services.kubernetes.kubelet.seedDockerImages = [
    sandboxImage
    caddyProxyImage
  ];
}

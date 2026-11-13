{
  clank,
  nixpkgs,
  pkgs,
  ...
}: let
  # opencode 2, as clank has it (with a fix for its build), since nixpkgs
  # 26.05 only has opencode 1, whose API differs
  opencode = clank.legacyPackages.${pkgs.stdenv.hostPlatform.system}.opencode;

  # What the agents reach through the credentials proxy
  # (./credentials-proxy.nix), which adds the credentials
  proxied = name: "http://${name}.credentials-proxy.svc.cluster.local";

  # opencode's configuration in the sandboxes: it reaches the model through
  # the proxy, and uses tools without asking, as nobody is there to ask.
  configuration = pkgs.writeText "opencode.json" (builtins.toJSON {
    "$schema" = "https://opencode.ai/config.json";
    model = "greenpt/glm-5.3";
    providers.greenpt.settings = {
      apiKey = "dummy";
      baseURL = "${proxied "model"}/v1";
    };
    permissions = [
      {
        action = "*";
        resource = "*";
        effect = "allow";
      }
      # The agent asks in its reply instead, which ./agents/AGENTS.md tells it
      {
        action = "question";
        resource = "*";
        effect = "deny";
      }
    ];
    instructions = ["${./agents/AGENTS.md}"];
    # Nor is anybody there to undo changes or share sessions
    snapshots = false;
    share = "disabled";
    update = "disable";
    websearch = false;
  });

  # git and glab reach GitLab through the proxy, as clank's do
  gitConfig = pkgs.writeTextDir "etc/gitconfig" ''
    [url "${proxied "gitlab"}/"]
    	insteadOf = git@git.magenta.dk:
    	insteadOf = https://git.magenta.dk/
    [user]
    	name = AI Bot
    	email = ai@magenta.dk
  '';
  glabConfig = pkgs.writeText "glab-config.yml" (builtins.toJSON {
    check_update = false;
    show_whats_new = false;
    telemetry = false;
    hosts = {
      # glab uses https unless told otherwise
      "gitlab.credentials-proxy.svc.cluster.local".api_protocol = "http";
      # Merge request URLs name git.magenta.dk
      "git.magenta.dk" = {
        api_protocol = "http";
        api_host = "gitlab.credentials-proxy.svc.cluster.local";
      };
    };
  });

  # Nix, for agents to install what they need: single-user, as root, with
  # `nixpkgs` the nixpkgs of anvil
  nixConfig = pkgs.runCommand "nix-config" {} ''
    mkdir -p $out/etc/nix
    cat > $out/etc/nix/nix.conf << 'EOF'
    experimental-features = nix-command flakes
    build-users-group =
    sandbox = false
    flake-registry =
    EOF
    cat > $out/etc/nix/registry.json << 'EOF'
    ${builtins.toJSON {
      version = 2;
      flakes = [
        {
          from = {
            type = "indirect";
            id = "nixpkgs";
          };
          to = {
            type = "github";
            owner = "NixOS";
            repo = "nixpkgs";
            inherit (nixpkgs) rev;
          };
        }
      ];
    }}
    EOF
  '';

  # podman, for agents to run containers, also as `docker`. In the sandbox's
  # VM, its storage goes through fuse-overlayfs, as the kernel's overlay
  # cannot write to virtio-fs, and its containers do without cgroups of their
  # own, as the VM does not hand its controllers down that far.
  containersConfig = pkgs.runCommand "containers-config" {} ''
    mkdir -p $out/etc/containers
    cat > $out/etc/containers/policy.json << 'EOF'
    {"default": [{"type": "insecureAcceptAnything"}]}
    EOF
    cat > $out/etc/containers/registries.conf << 'EOF'
    unqualified-search-registries = ["docker.io"]
    EOF
    cat > $out/etc/containers/storage.conf << 'EOF'
    [storage]
    driver = "overlay"
    graphroot = "/var/lib/containers/storage"
    runroot = "/run/containers/storage"

    [storage.options.overlay]
    mount_program = "/bin/fuse-overlayfs"
    EOF
    cat > $out/etc/containers/containers.conf << 'EOF'
    [containers]
    cgroups = "disabled"

    [engine]
    cgroup_manager = "cgroupfs"
    events_logger = "file"
    EOF
  '';
  docker = pkgs.writeShellScriptBin "docker" ''
    exec podman "$@"
  '';

  # FUSE is in the kernel of the sandbox's VM, but not among the devices of
  # its containers; the agent's container is privileged, so it may make it.
  start = pkgs.writeShellScriptBin "start-agent" ''
    [ -e /dev/fuse ] || mknod -m 666 /dev/fuse c 10 229 || true
    exec opencode serve --hostname 0.0.0.0 --port 4096 --print-logs
  '';

  image = pkgs.dockerTools.buildLayeredImageWithNixDb {
    name = "agent";
    contents = with pkgs; [
      # What programs expect to find on a system
      dockerTools.binSh
      dockerTools.caCertificates
      dockerTools.fakeNss
      dockerTools.usrBinEnv
      gitConfig
      nixConfig
      containersConfig
      start
      opencode
      (writeScriptBin "transcript" ''
        #!${python3}/bin/python3
        ${builtins.readFile ./agents/transcript.py}
      '')
      # Tools for the agent
      bashInteractive
      coreutils
      curl
      diffutils
      docker
      findutils
      fuse-overlayfs
      gawk
      git
      glab
      gnugrep
      gnused
      gnutar
      gzip
      iptables
      jq
      less
      nix
      patch
      podman
      procps
      python3
      ripgrep
      unzip
      which
      xz
    ];
    extraCommands = ''
      mkdir -p root tmp var/tmp var/lib/containers run workspace
      chmod 1777 tmp var/tmp
      # A copy, as glab insists on writing to its configuration
      install -D -m 600 ${glabConfig} root/.config/glab-cli/config.yml
    '';
    config = {
      Cmd = ["start-agent"];
      Env = [
        "PATH=/bin"
        "HOME=/root"
        "NIX_PATH=nixpkgs=flake:nixpkgs"
        "OPENCODE_CONFIG=${configuration}"
        "REDMINE_URL=${proxied "redmine"}"
        "GITLAB_HOST=${proxied "gitlab"}"
      ];
      WorkingDir = "/workspace";
    };
  };

  # The password of opencode's server, made up by the Redmine operator
  # (./redmine-operator.nix), which is its client
  password = {
    name = "OPENCODE_SERVER_PASSWORD";
    valueFrom.secretKeyRef = {
      name = "agent-server";
      key = "password";
    };
  };
in {
  services.k3s.images = [image];

  # The agents the Redmine operator (./redmine-operator.nix) has work on
  # tickets: opencode, run as a server in a sandbox (./agent-sandbox.nix) of
  # its own, which is a VM (./kata.nix) with a workspace volume, started as
  # the ticket is assigned. A sandbox's pod logs what its agent does, as it
  # does it:
  #
  #   sudo k3s kubectl -n agents logs -f -l sandbox.users.io/redmine-ticket=42 -c transcript
  #
  # They run in the namespace the operator serves, which it defines.
  services.k3s.manifests.agents.content = [
    {
      apiVersion = "extensions.agents.x-k8s.io/v1beta1";
      kind = "SandboxTemplate";
      metadata = {
        name = "agent";
        namespace = "agents";
      };
      spec = {
        podTemplate.spec = {
          runtimeClassName = "kata";
          containers = [
            {
              name = "agent";
              image = "${image.imageName}:${image.imageTag}";
              imagePullPolicy = "Never";
              env = [password];
              ports = [
                {
                  name = "opencode";
                  containerPort = 4096;
                }
              ];
              readinessProbe.tcpSocket.port = "opencode";
              # For podman. Privileged in the VM of the sandbox, not on the
              # laptop: Kata keeps the laptop's devices out of it.
              securityContext.privileged = true;
              # The workspace, opencode's sessions and container images
              # survive restarts of the sandbox
              volumeMounts = [
                {
                  name = "workspace";
                  mountPath = "/workspace";
                  subPath = "workspace";
                }
                {
                  name = "workspace";
                  mountPath = "/root/.local/share/opencode";
                  subPath = "opencode";
                }
                {
                  name = "workspace";
                  mountPath = "/var/lib/containers";
                  subPath = "containers";
                }
              ];
            }
            # Prints what the agent does to the pod's log (./agents/transcript.py)
            {
              name = "transcript";
              image = "${image.imageName}:${image.imageTag}";
              imagePullPolicy = "Never";
              command = ["transcript"];
              env = [password];
            }
          ];
        };
        volumeClaimTemplates = [
          {
            metadata.name = "workspace";
            spec = {
              accessModes = ["ReadWriteOnce"];
              resources.requests.storage = "10Gi";
            };
          }
        ];
        # agent-sandbox's default policy (the internet, but not the laptop,
        # its network or the cluster), plus what an agent needs of the
        # cluster: the credentials proxy and DNS to find it by, and the
        # operator talking to it.
        networkPolicy = {
          ingress = [
            {
              from = [
                {
                  namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "redmine-operator";
                  podSelector.matchLabels."app.kubernetes.io/name" = "redmine-operator";
                }
              ];
              ports = [
                {
                  protocol = "TCP";
                  port = 4096;
                }
              ];
            }
          ];
          egress = [
            {
              to = [
                {
                  namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "credentials-proxy";
                  podSelector.matchLabels."app.kubernetes.io/name" = "credentials-proxy";
                }
              ];
              ports = map (port: {
                protocol = "TCP";
                inherit port;
              }) [8080 8081 8082];
            }
            {
              to = [
                {
                  namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "kube-system";
                  podSelector.matchLabels.k8s-app = "kube-dns";
                }
              ];
              ports = [
                {
                  protocol = "UDP";
                  port = 53;
                }
                {
                  protocol = "TCP";
                  port = 53;
                }
              ];
            }
            {
              to = [
                {
                  ipBlock = {
                    cidr = "0.0.0.0/0";
                    except = ["10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "169.254.0.0/16"];
                  };
                }
                {
                  ipBlock = {
                    cidr = "::/0";
                    except = ["fc00::/7" "fe80::/10"];
                  };
                }
              ];
            }
          ];
        };
      };
    }
    {
      apiVersion = "extensions.agents.x-k8s.io/v1beta1";
      kind = "SandboxWarmPool";
      metadata = {
        name = "agent";
        namespace = "agents";
      };
      # Claims need a warm pool in agent-sandbox 1.0, but keeping sandboxes
      # started ahead of time saves little, as they start in seconds: with
      # none, a claim makes its own from the template.
      spec = {
        replicas = 0;
        sandboxTemplateRef.name = "agent";
      };
    }
  ];
}

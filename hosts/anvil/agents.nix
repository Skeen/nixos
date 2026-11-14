{
  clank,
  config,
  pkgs,
  ...
}: let
  # The system of the sandboxes: clank's, from its container modules and those
  # clank gets on anvil (../../modules/base/clank/modules.nix), made the
  # system of a Kata VM serving opencode by ./agents/sandbox.nix. So the
  # agents have the tools, skills and configuration of clank.
  sandbox = clank.inputs.nixpkgs.lib.nixosSystem {
    inherit (pkgs.stdenv.hostPlatform) system;
    specialArgs.inputs = clank.inputs;
    modules =
      [
        {nixpkgs.overlays = [clank.overlays.default];}
        "${clank}/container"
      ]
      ++ import ../../modules/base/clank/modules.nix {inherit clank;}
      ++ [./agents/sandbox.nix];
  };
  system = sandbox.config.system.build.toplevel;

  # The system as an image, with a Nix database for the store in it, booting
  # NixOS's init (systemd), which stops on SIGRTMIN+3 rather than SIGTERM
  image = pkgs.dockerTools.buildLayeredImageWithNixDb {
    name = "agent";
    contents = [
      (pkgs.runCommand "agent-root" {} ''
        mkdir -p $out/.sandbox $out/var
        ln -s ${system} $out/.sandbox/system
        ln -s /run $out/var/run
      '')
    ];
    maxLayers = 120;
    config = {
      Entrypoint = ["${system}/init"];
      Env = ["container=oci"];
      StopSignal = "SIGRTMIN+3";
    };
  };

  # Prints what the agent does to the pod's log (./agents/transcript.py)
  transcriptImage = pkgs.dockerTools.buildLayeredImage {
    name = "agent-transcript";
    contents = [
      (pkgs.writeScriptBin "transcript" ''
        #!${pkgs.python3}/bin/python3
        ${builtins.readFile ./agents/transcript.py}
      '')
    ];
    config.Cmd = ["/bin/transcript"];
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

  # The ports of the credentials proxy (./credentials-proxy.nix), as clank
  # has them at clank-proxy
  proxyPorts = [1655 1394 1932 1942 1974];
in {
  # The images go into containerd only when they are new: k3s would import
  # them again on every start, which takes a while for the system's. Pinned,
  # so that the kubelet does not remove them while no sandbox runs.
  systemd.services.agent-images = {
    description = "Import the images of agents' sandboxes into k3s";
    wantedBy = ["k3s.service"];
    after = ["k3s.service"];
    partOf = ["k3s.service"];
    restartTriggers = [image transcriptImage];
    path = [config.services.k3s.package];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "10s";
    };
    script = ''
      until k3s ctr version > /dev/null 2>&1; do
        sleep 2
      done
      for image in ${image}:${image.imageName}:${image.imageTag} ${transcriptImage}:${transcriptImage.imageName}:${transcriptImage.imageTag}; do
        IFS=: read -r archive name tag <<< "$image"
        reference="docker.io/library/$name:$tag"
        if ! k3s ctr -n k8s.io images ls -q | grep -qxF "$reference"; then
          k3s ctr -n k8s.io images import "$archive"
        fi
        k3s ctr -n k8s.io images label "$reference" io.cri-containerd.pinned=pinned > /dev/null
      done
    '';
  };

  # The agents the Redmine operator (./redmine-operator.nix) has work on
  # tickets: opencode, run as a server in a sandbox (./agent-sandbox.nix) of
  # its own, which is a VM (./kata.nix) with a volume of its own, started as
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
              ports = [
                {
                  name = "opencode";
                  containerPort = 4096;
                }
              ];
              readinessProbe.tcpSocket.port = "opencode";
              # For systemd and podman. Privileged in the VM of the sandbox,
              # not on the laptop: Kata keeps the laptop's devices out of it.
              securityContext.privileged = true;
              # The volume of the sandbox, where clank keeps what lasts:
              # opencode's sessions, container images and so on, as well as
              # the workspace
              volumeMounts =
                map (path: {
                  name = "workspace";
                  mountPath = "/${path}";
                  subPath = path;
                }) ["workspace" "disk" "persist"]
                ++ [
                  {
                    name = "agent-server";
                    mountPath = "/secrets/agent-server";
                    readOnly = true;
                  }
                ];
            }
            {
              name = "transcript";
              image = "${transcriptImage.imageName}:${transcriptImage.imageTag}";
              imagePullPolicy = "Never";
              env = [password];
            }
          ];
          volumes = [
            {
              name = "agent-server";
              secret.secretName = "agent-server";
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
              ports =
                map (port: {
                  protocol = "TCP";
                  inherit port;
                })
                proxyPorts;
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
    # Claims need a warm pool in agent-sandbox 1.0, but keeping sandboxes
    # started ahead of time saves little, as they start in seconds: with
    # none, a claim makes its own from the template.
    {
      apiVersion = "extensions.agents.x-k8s.io/v1beta1";
      kind = "SandboxWarmPool";
      metadata = {
        name = "agent";
        namespace = "agents";
      };
      spec = {
        replicas = 0;
        sandboxTemplateRef.name = "agent";
      };
    }
    # clank's modules reach the proxy as clank-proxy
    {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "clank-proxy";
        namespace = "agents";
      };
      spec = {
        type = "ExternalName";
        externalName = "clank-proxy.credentials-proxy.svc.cluster.local";
      };
    }
  ];
}

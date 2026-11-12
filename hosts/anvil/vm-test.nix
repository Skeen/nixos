# NixOS VM test of the cluster on anvil, and what runs on it: boots ./k3s.nix,
# ./redmine.nix, ./agent-sandbox.nix and ./kata.nix in a machine set up like
# anvil where it matters to the cluster (a root filesystem that does not
# survive a reboot, state on btrfs under /nix/persist, the firewall, and an
# uplink managed by NetworkManager), next to a second machine playing the
# network the laptop is on, as well as the internet. Sandboxes run in VMs in
# that VM, which needs nested virtualization. Run it with:
#
#   nix build -L .#checks.x86_64-linux.anvil-k3s
{pkgs, ...}: let
  # The test has no access to the network, so the images are pulled here, at
  # the tags of ./redmine.nix and ./agent-sandbox.nix, and loaded into the
  # cluster along with those of k3s itself.
  pulledImages = [
    (pkgs.dockerTools.pullImage {
      imageName = "docker.io/library/redmine";
      imageDigest = "sha256:eff65d7d651d8b07784cbaf37aec5aa74c1ccea3b834e8157e7043c003bdbf70";
      hash = "sha256-e3YjQFqKxOorXOSKkgA5+tzgNXgBOZjR3K8/A5vTEkU=";
      finalImageTag = "7.0.3";
    })
    (pkgs.dockerTools.pullImage {
      imageName = "docker.io/library/postgres";
      imageDigest = "sha256:e3d24f6906d0760bf4da0dae872415391ededefad23fd471c47dc53b0ddf3c42";
      hash = "sha256-Rh/6C97KlSceivNGAytLWQ0blYcXv7vDDWhwhwhjYRY=";
      finalImageTag = "18.6";
    })
    (pkgs.dockerTools.pullImage {
      imageName = "registry.k8s.io/agent-sandbox/agent-sandbox-controller";
      imageDigest = "sha256:594f4853913bca2b336d0267fe0978445f1aaa5837ed23797e48e745c8d6b610";
      hash = "sha256-rr/PCJvCwqyRUHEgMdzSS5S2FcLDlg6oA3Y6+98EKwA=";
      finalImageTag = "v1.0.10";
    })
  ];

  # The image for the pods below is built here.
  image = pkgs.dockerTools.buildImage {
    name = "test.local/workload";
    tag = "local";
    copyToRoot = pkgs.buildEnv {
      name = "workload-root";
      paths = [pkgs.busybox pkgs.curl];
      pathsToLink = ["/bin"];
    };
  };

  # A pod with a volume, serving that volume on port 8080. Its main process
  # ignores SIGTERM, as that of a sandbox is likely to.
  workload = pkgs.writeText "workload.json" (builtins.toJSON {
    apiVersion = "v1";
    kind = "List";
    items = [
      {
        apiVersion = "v1";
        kind = "PersistentVolumeClaim";
        metadata.name = "workload";
        spec = {
          accessModes = ["ReadWriteOnce"];
          resources.requests.storage = "1Gi";
        };
      }
      {
        apiVersion = "v1";
        kind = "Pod";
        metadata.name = "workload";
        spec = {
          containers = [
            {
              name = "workload";
              image = "${image.imageName}:${image.imageTag}";
              imagePullPolicy = "Never";
              command = ["sh" "-c" "httpd -p 8080 -h /data && exec sleep infinity"];
              volumeMounts = [
                {
                  name = "data";
                  mountPath = "/data";
                }
              ];
            }
          ];
          volumes = [
            {
              name = "data";
              persistentVolumeClaim.claimName = "workload";
            }
          ];
        };
      }
    ];
  });

  # A sandbox, and a template of sandboxes kept warm in a pool, one of which is
  # claimed. The template's sandboxes run in VMs (./kata.nix), with a workspace
  # volume of their own. It has no network policy of its own, so its sandboxes
  # get the one of agent-sandbox.
  sandboxes = let
    container = {
      name = "sandbox";
      image = "${image.imageName}:${image.imageTag}";
      imagePullPolicy = "Never";
      command = ["sleep" "infinity"];
    };
  in
    pkgs.writeText "sandboxes.json" (builtins.toJSON {
      apiVersion = "v1";
      kind = "List";
      items = [
        {
          apiVersion = "agents.x-k8s.io/v1beta1";
          kind = "Sandbox";
          metadata.name = "sandbox";
          spec.podTemplate.spec.containers = [container];
        }
        {
          apiVersion = "extensions.agents.x-k8s.io/v1beta1";
          kind = "SandboxTemplate";
          metadata.name = "template";
          spec = {
            podTemplate.spec = {
              runtimeClassName = "kata";
              containers = [
                (container
                  // {
                    volumeMounts = [
                      {
                        name = "workspace";
                        mountPath = "/workspace";
                      }
                    ];
                  })
              ];
            };
            volumeClaimTemplates = [
              {
                metadata.name = "workspace";
                spec = {
                  accessModes = ["ReadWriteOnce"];
                  resources.requests.storage = "1Gi";
                };
              }
            ];
          };
        }
        {
          apiVersion = "extensions.agents.x-k8s.io/v1beta1";
          kind = "SandboxWarmPool";
          metadata.name = "pool";
          spec = {
            replicas = 1;
            sandboxTemplateRef.name = "template";
          };
        }
        {
          apiVersion = "extensions.agents.x-k8s.io/v1beta1";
          kind = "SandboxClaim";
          metadata.name = "claim";
          spec.warmPoolRef.name = "pool";
        }
      ];
    });

  # The two networks anvil roams between, both provided by the `lan` machine.
  networks = {
    home = "192.168.1";
    work = "192.168.2";
  };
  # An address on the internet (one reserved for documentation), which the
  # `lan` machine has as well.
  internet = "203.0.113.1";
in {
  name = "anvil-k3s";

  nodes.anvil = {
    config,
    impermanence,
    lib,
    ...
  }: {
    imports = [
      impermanence.nixosModules.impermanence
      ./k3s.nix
      ./redmine.nix
      ./agent-sandbox.nix
      ./kata.nix
    ];

    virtualisation = {
      cores = 4;
      memorySize = 8192;
      # Keep the root filesystem in memory, to lose it on reboot like anvil
      # does, and persist to a disk with btrfs on it.
      diskImage = null;
      emptyDiskImages = [
        {
          size = 8192;
          driveConfig.deviceExtraOpts.serial = "persist";
        }
      ];
      fileSystems."/nix/persist" = {
        device = "/dev/disk/by-id/virtio-persist";
        fsType = "btrfs";
        autoFormat = true;
        neededForBoot = true;
        options = ["compress=zstd" "noatime"];
      };
    };
    environment.persistence."/nix/persist".hideMounts = true;

    # Let NetworkManager, and only NetworkManager, configure the uplink
    networking.useDHCP = false;
    networking.interfaces = lib.mkForce {eth1 = {};};
    networking.networkmanager = {
      enable = true;
      settings.main.no-auto-default = "*";
      ensureProfiles.profiles =
        lib.mapAttrs (name: network: {
          connection = {
            id = name;
            type = "ethernet";
            interface-name = "eth1";
            autoconnect = name == "home";
          };
          ipv4 = {
            method = "manual";
            address1 = "${network}.2/24,${network}.1";
            dns = "${network}.1;";
          };
          ipv6.method = "disabled";
        })
        networks;
    };

    services.k3s.images =
      [
        config.services.k3s.package.airgap-images
        image
      ]
      ++ pulledImages;
  };

  nodes.lan = {
    lib,
    pkgs,
    ...
  }: {
    networking.useDHCP = false;
    networking.firewall.enable = false;
    networking.interfaces = lib.mkForce {
      eth1.ipv4.addresses =
        map (network: {
          address = "${network}.1";
          prefixLength = 24;
        })
        (lib.attrValues networks)
        ++ [
          {
            address = internet;
            prefixLength = 32;
          }
        ];
    };
    environment.systemPackages = [pkgs.curl pkgs.dnsutils];

    systemd.services =
      {
        web = {
          wantedBy = ["multi-user.target"];
          serviceConfig.ExecStart = "${pkgs.busybox}/bin/httpd -f -p 80 -h ${pkgs.writeTextDir "index.html" "hello from lan\n"}";
        };
      }
      # A nameserver per network, each resolving `where.test` to its own
      # address, which tells the nameserver in use.
      // lib.mapAttrs' (name: network:
        lib.nameValuePair "dns-${name}" {
          wantedBy = ["multi-user.target"];
          after = ["network-online.target"];
          wants = ["network-online.target"];
          serviceConfig = {
            ExecStart = "${pkgs.dnsmasq}/bin/dnsmasq --keep-in-foreground --conf-file=/dev/null --pid-file=/run/dns-${name}.pid --no-resolv --no-hosts --bind-interfaces --listen-address=${network}.1 --address=/where.test/${network}.1";
            Restart = "always";
          };
        })
      networks;
  };

  testScript = ''
    import re
    import time


    def pod(command):
        return anvil.succeed(f"kubectl exec workload -- {command}")


    def redmine(path, *options):
        # Browse Redmine on the laptop, keeping the session in /tmp/cookies
        return anvil.succeed(f"curl -sf -m 10 -b /tmp/cookies -c /tmp/cookies {' '.join(options)} http://redmine.localhost{path}")


    def authenticity_token(page):
        # The token Rails expects with forms posted from the page
        match = re.search(r'name="authenticity_token" value="([^"]+)"', page)
        assert match is not None, "no authenticity token on the page"
        return match.group(1)


    def logged_in_to_redmine():
        # Pages for users only redirect everyone else: to the login page, or
        # to change their password first.
        return redmine("/my/account", "-o /dev/null -w '%{http_code}'") == "200"


    def log_in_to_redmine(password):
        token = authenticity_token(redmine("/login"))
        redmine("/login", f"--data-urlencode 'authenticity_token={token}'", f"-d username=admin -d password={password}")


    def pod_reaches_api_server(timeout=None):
        # An unauthorized request is still a request served by the API server
        command = "kubectl exec workload -- curl -sk -m 5 -o /dev/null -w '%{http_code}' https://kubernetes.default.svc/version | grep 401"
        if timeout is None:
            anvil.succeed(command)
        else:
            anvil.wait_until_succeeds(command, timeout=timeout)


    def pod_resolves_through(nameserver):
        anvil.wait_until_succeeds(
            f"kubectl exec workload -- nslookup -type=a where.test | grep 'Address: {nameserver}'",
            timeout=60,
        )


    start_all()

    with subtest("the cluster comes up"):
        anvil.wait_for_unit("k3s.service")
        anvil.wait_until_succeeds("kubectl wait --for=condition=Ready node/anvil --timeout=5s", timeout=300)
        anvil.wait_until_succeeds("kubectl get serviceaccount default", timeout=300)

    with subtest("a pod with a volume runs"):
        anvil.succeed("kubectl apply -f ${workload}")
        anvil.wait_until_succeeds("kubectl wait --for=condition=Ready pod/workload --timeout=5s", timeout=300)
        pod("sh -c 'echo persistent > /data/marker'")

    with subtest("pods reach the API server, name resolution and the network"):
        pod_reaches_api_server()
        pod_resolves_through("${networks.home}.1")
        assert "hello from lan" in pod("curl -sf -m 5 http://${networks.home}.1/")

    with subtest("the cluster is not exposed to the network of the laptop"):
        address = anvil.succeed("kubectl get pod workload -o jsonpath='{.status.podIP}'").strip()
        # The pod is reachable from the host, and the host from the network,
        anvil.succeed(f"curl -sf -m 5 http://{address}:8080/marker")
        lan.succeed("ping -c 1 -W 2 ${networks.home}.2")
        # but routing the networks of the cluster through the host gets nowhere:
        for network in ["10.41.0.1/32", "10.42.0.0/16", "10.43.0.0/16"]:
            lan.succeed(f"ip route add {network} via ${networks.home}.2")
        # neither to a pod,
        lan.fail(f"curl -sf -m 5 http://{address}:8080/marker")
        # nor to services (cluster DNS, the API server),
        lan.fail("dig +time=2 +tries=1 @10.43.0.10 kubernetes.default.svc.cluster.local")
        lan.fail("curl -sk -m 5 https://10.43.0.1/version")
        # nor to the API server and the DNS forwarder on the host itself.
        lan.fail("curl -sk -m 5 https://${networks.home}.2:6443/version")
        lan.fail("curl -sk -m 5 https://10.41.0.1:6443/version")
        lan.fail("dig +time=2 +tries=1 @10.41.0.1 where.test")

    with subtest("Redmine comes up, with its database off the network"):
        anvil.wait_until_succeeds("curl -sf -m 5 -o /dev/null http://redmine.localhost/login", timeout=900)
        address = anvil.succeed("kubectl -n redmine get pods -o jsonpath='{.items[0].status.podIP}'").strip()
        anvil.succeed(f"bash -c '</dev/tcp/{address}/3000'")
        anvil.fail(f"bash -c '</dev/tcp/{address}/5432'")

    with subtest("Redmine is reachable from the laptop and from pods, not from the network"):
        # The service only gets to Redmine once its readiness probe has passed
        anvil.wait_until_succeeds("kubectl exec workload -- curl -sf -m 10 -o /dev/null http://redmine.redmine.svc.cluster.local/login", timeout=60)
        lan.fail("curl -sf -m 5 -o /dev/null http://${networks.home}.2/login")

    with subtest("logging in to Redmine, which has admin change the default password first"):
        log_in_to_redmine("admin")
        assert redmine("/my/account", "-o /dev/null -w '%{redirect_url}'").endswith("/my/password")
        token = authenticity_token(redmine("/my/password"))
        redmine("/my/password", f"--data-urlencode 'authenticity_token={token}'", "-d password=admin -d new_password=Correct-Horse-1 -d new_password_confirmation=Correct-Horse-1")
        assert logged_in_to_redmine()
        cookies = anvil.succeed("cat /tmp/cookies")

    with subtest("sandboxes run, by themselves and from a template"):
        anvil.wait_until_succeeds("kubectl -n agent-sandbox-system rollout status deployment/agent-sandbox-controller --timeout=5s", timeout=300)
        anvil.succeed("kubectl apply -f ${sandboxes}")
        anvil.wait_until_succeeds("kubectl wait --for=condition=Ready sandbox/sandbox sandboxclaim/claim --timeout=5s", timeout=300)
        claimed = anvil.succeed("kubectl get sandboxclaim claim -o jsonpath='{.status.sandbox.name}'").strip()

    with subtest("sandboxes made from the template run in VMs of their own, with their workspace"):
        kernel = anvil.succeed("uname -r")
        assert anvil.succeed("kubectl exec sandbox -- uname -r") == kernel
        assert anvil.succeed(f"kubectl exec {claimed} -- uname -r") != kernel, "the sandbox runs on the kernel of the laptop"
        anvil.succeed(f"kubectl exec {claimed} -- sh -c 'echo persistent > /workspace/marker'")

    with subtest("sandboxes made from a template reach the internet, not the laptop, its network or the cluster"):
        redmine_address = anvil.succeed("kubectl -n redmine get service redmine -o jsonpath='{.spec.clusterIP}'").strip()
        anvil.succeed(f"kubectl exec {claimed} -- curl -sf -m 5 -o /dev/null http://${internet}/")
        for url in ["http://${networks.home}.1/", "https://10.41.0.1:6443/version", "https://10.43.0.1/version", f"http://{redmine_address}/login"]:
            # Once the network policy controller has caught up with the pod
            anvil.wait_until_fails(f"kubectl exec {claimed} -- curl -sk -m 5 -o /dev/null {url}", timeout=60)

    with subtest("pods reach only the ports of the laptop the cluster needs"):
        anvil.succeed("systemd-run --unit listener ${pkgs.busybox}/bin/httpd -f -p 8888 -h /var/empty")
        anvil.wait_until_succeeds("curl -s -m 5 -o /dev/null http://10.41.0.1:8888/")
        pod("curl -sk -m 5 -o /dev/null https://10.41.0.1:6443/version")
        anvil.fail("kubectl exec workload -- curl -s -m 5 -o /dev/null http://10.41.0.1:8888/")
        anvil.fail("kubectl exec workload -- curl -s -m 5 -o /dev/null http://${networks.home}.2:8888/")

    with subtest("the cluster keeps working as the laptop roams to another network"):
        anvil.succeed("nmcli connection up work")
        anvil.wait_until_succeeds("ip -4 address show eth1 | grep ${networks.work}.2")
        pod_reaches_api_server()
        pod_resolves_through("${networks.work}.1")
        assert "hello from lan" in pod("curl -sf -m 5 http://${networks.work}.1/")

    with subtest("the cluster keeps working, and starts, without a network"):
        anvil.succeed("nmcli device disconnect eth1")
        anvil.fail("ip route show default | grep .")
        pod_reaches_api_server()
        anvil.succeed("systemctl restart k3s")
        pod_reaches_api_server(timeout=300)

    with subtest("the cluster survives a reboot wiping the root filesystem"):
        start = time.monotonic()
        anvil.shutdown()
        duration = time.monotonic() - start
        assert duration < 60, f"shutting down took {duration:.0f}s, are containers holding it up?"

        anvil.start()
        anvil.wait_for_unit("k3s.service")
        # The pod is started again, with its volume
        anvil.wait_until_succeeds("kubectl exec workload -- cat /data/marker | grep persistent", timeout=300)
        # So is the sandbox, in a new VM, with its workspace
        anvil.wait_until_succeeds(f"kubectl exec {claimed} -- cat /workspace/marker | grep persistent", timeout=300)
        pod_reaches_api_server(timeout=300)
        pod_resolves_through("${networks.home}.1")
        # Redmine is back, with its database and the key sessions are signed
        # with: the session from before is still logged in, and the password
        # is the one it was changed to.
        anvil.wait_until_succeeds("curl -sf -m 5 -o /dev/null http://redmine.localhost/login", timeout=600)
        anvil.succeed(f"cat > /tmp/cookies << 'EOF'\n{cookies.strip()}\nEOF")
        assert logged_in_to_redmine(), "the session did not survive the reboot"
        anvil.succeed("rm /tmp/cookies")
        log_in_to_redmine("Correct-Horse-1")
        assert logged_in_to_redmine(), "could not log in with the changed password"
  '';
}

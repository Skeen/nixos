# Single-node Kubernetes cluster: control plane (apiserver, etcd, scheduler,
# controller-manager, addon-manager) and kubelet with containerd running on the
# same machine. Sandbox workloads run as Kata (QEMU) MicroVMs via a containerd
# runtime handler + RuntimeClass.
#
# See: https://wiki.nixos.org/wiki/Kubernetes
#      https://kubernetes.io/docs/concepts/containers/runtime-class/
{
  config,
  lib,
  pkgs,
  ...
}: let
  kata = pkgs.kata-runtime;
in {
  # --- Kata Containers (QEMU MicroVMs) -------------------------------------
  virtualisation.containerd = {
    enable = true;
    settings = {
      plugins."io.containerd.grpc.v1.cri".containerd.runtimes = {
        # The default runc handler stays for the cluster's own control plane
        # pods (etcd, coredns, agent-sandbox-controller), matching what
        # services.kubernetes.kubelet sets up by default.
        runc = {
          runtime_type = "io.containerd.runc.v2";
          options.SystemdCgroup = true;
        };
        # Kata: each pod gets its own QEMU MicroVM with a dedicated guest
        # kernel. runtime_path pins the shim binary (containerd only looks in
        # its own PATH otherwise, which doesn't include kata). It reads
        # ${kata}/share/defaults/kata-containers/configuration.toml
        # (nixpkgs pins the hypervisor to qemu_kvm).
        kata = {
          runtime_type = "io.containerd.kata.v2";
          runtime_path = "${kata}/bin/containerd-shim-kata-v2";
          # Sandboxes run untrusted generated code; never give them host
          # devices (e.g. /dev/kvm) or privileged host namespaces.
          privileged_without_host_devices = true;
          pod_annotations = [
            "io.containerd.runtime.v2.task"
            "io.katacontainers.*"
          ];
        };
      };
    };
  };

  # kata on the host PATH for manual debugging (`kata-runtime exec ...`)
  environment.systemPackages = [kata];

  # Kata's default config starts each VM with 1 vCPU and hot-adds more to
  # match the container's CPU request. ACPI CPU hotplug does not work in
  # nested QEMU ("failed to hot add vCPUs: only 0 vCPUs of 1 were added"),
  # so pre-allocate enough vCPUs to satisfy the largest sandbox request and
  # skip hotplug entirely. The shim picks /etc/kata-containers/ over the
  # store copy automatically.
  #
  # The kernel_params override drops upstream's "cgroup_no_v1=all
  # systemd.unified_cgroup_hierarchy=1". Forcing the guest to cgroup v1
  # (the would-be fix for exec) demonstrably hangs the kata agent here:
  # the shim stops answering and StartContainer times out, so shells into
  # systemd-as-PID1 sandboxes stay broken under kata 3.16 for exec
  # (kata-containers#10733; fixed upstream in 4.2 via #13627). The
  # supported way in is SSH through the clank-ssh NodePort Service
  # (see sandbox.nix: sshd inside the sandbox image; ssh root@golem -p 32222).
  environment.etc."kata-containers/configuration.toml".source = pkgs.runCommand "kata-configuration.toml" {} ''
    sed -E \
      -e 's/^default_vcpus *=.*/default_vcpus = 4/' \
      -e 's/^default_maxvcpus *=.*/default_maxvcpus = 4/' \
      -e 's|^kernel_params *=.*|kernel_params = ""|' \
      "${kata}/share/defaults/kata-containers/configuration.toml" > "$out"
  '';

  # /dev/kvm is required by Kata's default QEMU configuration
  users.groups.kvm = {};

  # The kubelet preStart seeds images (incl. the ~700MB sandbox image) via
  # `ctr import`; the 90s default would kill it mid-import on slow disks.
  systemd.services.kubelet.serviceConfig.TimeoutStartSec = "30min";

  # --- Cluster -------------------------------------------------------------
  services.kubernetes = {
    # Control plane + worker on this node, with RBAC.
    roles = ["master" "node"];
    package = pkgs.kubernetes;
    masterAddress = "golem.cluster.local";

    # apiserver address used by all components' kubeconfigs
    apiserverAddress = "https://golem.cluster.local:6443";

    easyCerts = true; # let the module issue x509 certs via cfssl/certmgr
    dataDir = "/var/lib/kubernetes"; # (also the default)

    clusterCidr = "10.42.0.0/16"; # pod network (flannel vxlan)
    apiserver = {
      securePort = 6443;
      # The cert issued for the apiserver must cover every name clients use.
      extraSANs = [
        "golem"
        "golem.cluster.local"
        config.networking.hostName
      ];
      # Required for kubectl exec/port-forward into sandboxes
      allowPrivileged = true;
    };

    # Sandbox pods are created by the agent-sandbox controller via the CRD,
    # but exec'd into from the host; disable the default "unschedulable"
    # taint that role="master" would set (we ARE also the node).
    kubelet = {
      # Keep control plane pods schedulable (single node).
      unschedulable = false;
      # Kata needs quite a lot of /proc/sys, so allow the kubelet its defaults
      # for the runc-managed control plane pods, but pin the runtime endpoint.
      containerRuntimeEndpoint = "unix:///run/containerd/containerd.sock";
      # Give coredns the cluster DNS IP (matches the dns addon default:
      # serviceClusterIpRange 10.0.0.0/24 -> x.y.z.254)
      clusterDns = ["10.0.0.254"];
      clusterDomain = "cluster.local";
    };

    # Pod-to-pod + pod-to-internet networking via flannel's vxlan
    flannel.enable = true;

    # NodePorts + apiserver on the host firewall. Everything else is behind
    # Hetzner's cloud firewall.
    addons.dns.enable = true;
    addons.dns.replicas = 1; # single node
  };

  # Flannel uses the default-route interface (resolved dynamically; both the
  # Hetzner NIC and the test VM NIC do DHCP). Let flannel autodetect it.
  services.flannel.iface = lib.mkDefault null;

  # The apiserver cert is issued for golem.cluster.local (masterAddress) + the
  # node IP; make /etc/hosts resolve that name locally so the local kubeconfig
  # works even before real DNS is set up.
  networking.extraHosts = ''
    127.0.0.1 golem.cluster.local
  '';

  # Firewall: expose only what the cluster needs from the outside.
  networking.firewall = {
    allowedTCPPorts = [
      6443 # kubernetes apiserver
      10250 # kubelet (kubectl logs/exec)
    ];
    # Flannel vxlan (single node, but keep for future nodes)
    allowedUDPPorts = [8472];
    # NodePort range: sandbox ingress from the Hetzner firewall
    allowedTCPPortRanges = [
      {
        from = 30000;
        to = 32767;
      }
    ];
    allowedUDPPortRanges = [
      {
        from = 30000;
        to = 32767;
      }
    ];
  };

  # Forward traffic for pods (+ flannel vxlan). `net.ipv4.ip_forward` is set
  # by the kubelet module, but the network-interfaces module defaults
  # `net.ipv4.conf.all.forwarding` to 0 unless some interface sets proxyARP -
  # force it on or forwarded packets get dropped.
  boot.kernel.sysctl = {
    "net.ipv4.conf.all.forwarding" = lib.mkForce 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };
}

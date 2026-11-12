{
  lib,
  pkgs,
  ...
}: let
  # The address the node goes by in the cluster, see the node address below.
  nodeInterface = "k3s0";
  nodeAddress = "10.41.0.1";
in {
  # K3s is a lightweight Kubernetes distribution: the control plane, kubelet,
  # container runtime, pod network (flannel), DNS (CoreDNS), a storage
  # provisioner (local-path) and a network policy controller all run from a
  # single service. This is a single-node cluster, managed with
  # `sudo k3s kubectl`; the admin kubeconfig is deliberately left readable by
  # root only, as it would hand its readers root on the host.
  # https://wiki.nixos.org/wiki/K3s
  # https://docs.k3s.io

  services.k3s = {
    enable = true;
    nodeIP = nodeAddress;
    # Leave out the ingress controller, and the load balancer publishing it on
    # every address of the host. What the laptop should reach is published on
    # its loopback address instead, see ./redmine.nix. Also leave out the
    # runtime classes k3s adds for alternative container runtimes, none of
    # which are installed; see ./kata.nix for the one that is.
    disable = ["traefik" "servicelb" "runtimes"];
    extraFlags = [
      # Flannel would otherwise bind to the interface holding the default
      # route, which a laptop does not always have.
      "--flannel-iface=${nodeInterface}"
      # See the DNS forwarder below.
      "--resolv-conf=${pkgs.writeText "k3s-resolv.conf" "nameserver ${nodeAddress}\n"}"
    ];
  };

  # Kubernetes expects a node to keep its address: it is what the API server
  # advertises to the pods. A laptop's address however changes whenever it
  # moves to another network, and at times it has none at all. Left to its own
  # devices k3s uses the address of the uplink, so after roaming the pods would
  # be talking to an API server that is no longer there. Therefore the node gets
  # an address of its own on a dummy interface, which never changes and is
  # always up, making the cluster independent of the network the laptop is on.
  systemd.services.k3s-node-address = {
    description = "Node address for k3s";
    requiredBy = ["k3s.service" "dnsmasq.service"];
    before = ["k3s.service" "dnsmasq.service"];
    path = [pkgs.iproute2];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ip link show ${nodeInterface} > /dev/null 2>&1 || ip link add ${nodeInterface} type dummy
      ip address replace ${nodeAddress}/32 dev ${nodeInterface}
      ip link set ${nodeInterface} up
    '';
    postStop = ''
      ip link delete ${nodeInterface} || true
    '';
  };

  # Pods resolve names through CoreDNS, which forwards everything outside the
  # cluster to the nameservers found in resolv.conf when it started. On a
  # laptop those are the nameservers of whichever network it was on back then.
  # Instead point it at a forwarder on the node address, which follows the
  # resolv.conf of the host as NetworkManager rewrites it. It only serves the
  # cluster; the host itself keeps resolving as before.
  services.dnsmasq = {
    enable = true;
    resolveLocalQueries = false;
    settings = {
      listen-address = nodeAddress;
      bind-interfaces = true;
      no-hosts = true;
    };
  };

  networking.firewall = let
    # What the pods of the cluster need from the host itself: DNS (the
    # forwarder above), the API server and the kubelet (for metrics-server).
    podTCPPorts = [53 6443 10250];
    podUDPPorts = [53];

    # The network policy controller of k3s accepts whatever the network
    # policies allow a pod, which without any policies is everything, ahead of
    # the rules of this firewall, and k3s keeps inserting its own rules at the
    # top of the filter table in general. These rules therefore go into the
    # mangle table, which comes first.
    ports = lib.concatMapStringsSep "," toString;
    rules = [
      # K3s enables IP forwarding and flannel accepts all forwarded traffic to
      # the pod network. Any machine on the same network as the laptop could
      # reach the pods, and through them the services of the cluster, simply
      # by routing the pod network through anvil. Only let connections to pods
      # originate from other pods or from the host.
      "FORWARD -o cni0 ! -i cni0 -m conntrack --ctstate NEW -j DROP"
      # Pods, such as sandboxes running whatever an agent came up with, could
      # otherwise connect to anything listening on the laptop. Only let them
      # connect to what the cluster needs.
      "INPUT -i cni0 -p tcp -m conntrack --ctstate NEW -m multiport ! --dports ${ports podTCPPorts} -j DROP"
      "INPUT -i cni0 -p udp -m conntrack --ctstate NEW -m multiport ! --dports ${ports podUDPPorts} -j DROP"
    ];
  in {
    # For pods the network policy controller has not caught up with yet
    interfaces.cni0 = {
      allowedTCPPorts = podTCPPorts;
      allowedUDPPorts = podUDPPorts;
    };
    extraCommands =
      lib.concatMapStrings (rule: ''
        ip46tables -t mangle -D ${rule} 2> /dev/null || true
        ip46tables -t mangle -A ${rule}
      '')
      rules;
    extraStopCommands =
      lib.concatMapStrings (rule: ''
        ip46tables -t mangle -D ${rule} 2> /dev/null || true
      '')
      rules;
  };

  # Use Google's Docker Hub mirror for everything docker.io, like podman does.
  # https://docs.k3s.io/installation/private-registry
  environment.etc."rancher/k3s/registries.yaml".text = ''
    mirrors:
      docker.io:
        endpoint:
          - "https://mirror.gcr.io"
  '';

  # Containers are stopped by systemd on shutdown, which gives them the default
  # 90 seconds to react to SIGTERM before killing them. Any container whose
  # main process has no handler for it (a shell, `sleep infinity`) ignores the
  # signal, and so holds up the shutdown for the full duration.
  systemd.units."cri-containerd-.scope" = {
    overrideStrategy = "asDropin";
    text = ''
      [Scope]
      TimeoutStopSec=10s
    '';
  };

  environment.persistence."/nix/persist" = {
    directories = [
      # The state of the cluster: datastore, certificates, container images
      # and the volumes of the storage provisioner.
      {
        directory = "/var/lib/rancher/k3s";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # The volumes of the pods
      {
        directory = "/var/lib/kubelet";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # The password the node registered itself with. K3s generates a new one
      # when it is missing, which then fails validation against the datastore.
      {
        directory = "/etc/rancher/node";
        user = "root";
        group = "root";
        mode = "0755";
      }
      # The addresses handed out to pods (/var/lib/cni) are left out on
      # purpose: every pod gets a new one on boot anyway.
    ];
  };
}

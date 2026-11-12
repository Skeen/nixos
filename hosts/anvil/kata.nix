{pkgs, ...}: let
  kata = pkgs.kata-runtime;

  # Kata comes with a configuration for each hypervisor it supports. The one
  # for Cloud Hypervisor points at a binary the package does not include, so
  # use the one of nixpkgs. A VM gets 1 vCPU and 2 GiB of memory, plus what the
  # containers in it are limited to.
  configuration = pkgs.runCommand "kata-configuration-clh.toml" {} ''
    sed 's|^path = .*|path = "${pkgs.cloud-hypervisor}/bin/cloud-hypervisor"|' \
      ${kata}/share/defaults/kata-containers/configuration-clh.toml > $out
  '';

  # Merged into the configuration of the containerd of k3s, which imports the
  # files in config-v3.toml.d.
  runtime = (pkgs.formats.toml {}).generate "kata.toml" {
    version = 3;
    plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata = {
      runtime_type = "io.containerd.kata.v2";
      runtime_path = "${kata}/bin/containerd-shim-kata-v2";
      # Privileged containers get the devices of their VM, not of the laptop
      privileged_without_host_devices = true;
      options.ConfigPath = "${configuration}";
    };
  };
in {
  # Kata Containers runs each pod in a lightweight VM of its own, with a kernel
  # of its own, as a runtime of the containerd of k3s. Pods, such as sandboxes,
  # choose it with `runtimeClassName: kata`, and are otherwise unchanged:
  # volumes are shared into the VM (virtio-fs), and networking, network
  # policies included, works as for any other pod.
  #
  # The VMs run on Cloud Hypervisor, a lightweight virtual machine monitor in
  # the spirit of Firecracker, which unlike Firecracker can share volumes with
  # the VM. To use QEMU instead, point ConfigPath at configuration-qemu.toml.
  # https://katacontainers.io
  # https://github.com/kata-containers/kata-containers/tree/main/docs
  systemd.tmpfiles.settings."10-k3s-kata"."/var/lib/rancher/k3s/agent/etc/containerd/config-v3.toml.d/kata.toml"."L+".argument = "${runtime}";
  # containerd only reads its configuration when it starts, which is with k3s
  systemd.services.k3s.restartTriggers = [runtime];

  services.k3s.manifests.kata.content = {
    apiVersion = "node.k8s.io/v1";
    kind = "RuntimeClass";
    metadata.name = "kata";
    handler = "kata";
    # What a VM costs on top of the containers in it, for the scheduler
    overhead.podFixed = {
      cpu = "250m";
      memory = "130Mi";
    };
  };
}

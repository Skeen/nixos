{pkgs, ...}: let
  version = "v1.0.10";
in {
  # Agent Sandbox runs isolated, stateful workloads for agents on Kubernetes. A
  # `Sandbox` is a single pod with a stable identity and optionally persistent
  # volumes, which can be suspended and resumed. On top of that, a
  # `SandboxTemplate` describes a kind of sandbox, a `SandboxWarmPool` keeps
  # some started ahead of time, and a `SandboxClaim` takes one from a pool.
  #
  # Sandboxes made from a template get a network policy unless the template has
  # its own: they reach the internet, but not the laptop, its network or the
  # rest of the cluster (see ./vm-test.nix). Sandboxes created directly do not.
  # With `runtimeClassName: kata` in its pod template, a sandbox runs in a VM
  # of its own, see ./kata.nix.
  #
  # The release manifest has the custom resources and the controller, which
  # runs in the agent-sandbox-system namespace.
  # https://github.com/kubernetes-sigs/agent-sandbox
  # https://agent-sandbox.sigs.k8s.io/docs/
  services.k3s.manifests.agent-sandbox.source = pkgs.fetchurl {
    url = "https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${version}/sandbox-with-extensions.yaml";
    hash = "sha256-fMHsovtFhEsOwMNfyXU0DcAa8plDAf+ovwXbGtHjl+4=";
  };
}

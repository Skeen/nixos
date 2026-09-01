# kubernetes-sigs/agent-sandbox: the Sandbox/SandboxTemplate/SandboxClaim/
# SandboxWarmPool CRDs and controller, plus the `kata` RuntimeClass that maps
# pods to our containerd Kata (QEMU MicroVM) handler.
#
# https://github.com/kubernetes-sigs/agent-sandbox
# https://agent-sandbox.sigs.k8s.io
{
  config,
  lib,
  pkgs,
  ...
}: let
  version = "v1.0.0";

  # Pinned install manifest: CRDs + RBAC + controller Deployment (extensions
  # enabled: SandboxTemplate/SandboxClaim/SandboxWarmPool).
  sandboxManifest = pkgs.fetchurl {
    name = "agent-sandbox-with-extensions";
    url = "https://github.com/kubernetes-sigs/agent-sandbox/releases/download/${version}/sandbox-with-extensions.yaml";
    hash = "sha256-OiL4nKHR1ghOCjUXlyJIQu5BNkHWlF+eWyy14fbPAmw=";
  };
in {
  # One-shot installer: applies the CRDs + controller + RuntimeClass.
  # Runs on every activation/boot; `kubectl apply` is idempotent.
  systemd.services.agent-sandbox-install = {
    description = "Install agent-sandbox CRDs, controller and kata RuntimeClass";
    wantedBy = ["multi-user.target"];
    # Unit ordering: the CRDs must exist before the addon manager applies our
    # SandboxTemplate/Claim/WarmPool addons, but kube-addon-manager retries
    # failed addons anyway (it loops forever), so waiting here is safe.
    after = ["kube-apiserver.service"];
    wants = ["kube-addon-manager.service"];
    # wants (not requires): kube-apiserver crash-loops during early cert
    # bootstrap; requires would propagate each stop and TERM our oneshots
    # until systemd rates-limits them into permanent failure.
    # Wait for the apiserver to accept connections, then apply.
    path = [pkgs.kubernetes];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "10min";
      # Kill-switch races: at boot the unit can be stopped (TERM) while
      # still waiting for the apiserver; without this systemd marks the
      # oneshot permanently failed after its 5 default retries.
      Restart = "on-failure";
      RestartSec = "15s";
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
      kubectl get --raw=/readyz >/dev/null

      echo "Applying agent-sandbox ${version} (CRDs + controller + extensions)..."
      kubectl apply -f ${sandboxManifest}

      echo "Applying the kata RuntimeClass..."
      kubectl apply -f ${pkgs.writeText "kata-runtimeclass.yaml" (builtins.toJSON {
        apiVersion = "node.k8s.io/v1";
        kind = "RuntimeClass";
        metadata.name = "kata";
        handler = "kata";
        overhead = {
          # qemu VM fixed cost (podFixed, not per-container)
          podFixed = {
            cpu = "250m";
            memory = "128Mi";
          };
        };
        scheduling.nodeSelector."kubernetes.io/os" = "linux";
      })}

      echo "Waiting for the agent-sandbox controller to roll out..."
      kubectl -n agent-sandbox-system rollout status deploy/agent-sandbox-controller --timeout=180s || true
    '';
  };

  # agent-sandbox-install relies on services.kubernetes.pki (easyCerts) for
  # the cluster-admin kubeconfig used above.
  assertions = [
    {
      assertion = config.services.kubernetes.pki.enable;
      message = "golem: agent-sandbox-install relies on services.kubernetes.pki (easyCerts) for a cluster-admin kubeconfig";
    }
  ];
}

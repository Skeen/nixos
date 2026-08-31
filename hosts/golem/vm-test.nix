# NixOS VM test for golem: boots the actual host configuration in QEMU and
# asserts that the Kubernetes control plane, the agent-sandbox controller and
# a claimed Kata sandbox come up.
#
# Exposed through flake.nix as `nixosTests.golem`; run with a stubbed secrets
# input so it works without git+ssh access to nixos-secret:
#
#   nix build --no-link --print-out-paths \
#     --override-input secrets /tmp/empty-flake \
#     '.#nixosTests.golem'
#
# The sandbox VM runs Kata/QEMU inside this QEMU test VM (nested
# virtualization), so sandbox claims boot slowly; timeouts are generous:
#   1. waits for the control plane + agent-sandbox controller,
#   2. waits for the addon-manager to apply the sandbox resources,
#   3. waits for a sandbox pod (claimed from the warm pool) to run,
#   4. execs into the pod to prove the MicroVM is reachable.
{
  inputs, # the flake's inputs (resolved by flake.nix; no getFlake at runtime)
  ...
}: let
  testLib = import "${inputs.nixpkgs}/nixos/lib" {lib = inputs.nixpkgs.lib;};
in
  testLib.runTest {
    name = "golem-vm";

    hostPkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;

    nodes.golem = {
      imports = [./.]; # hosts/golem
    };

    # Flake inputs as plain module args (exactly what hosts/golem expects).
    defaults._module.args = {
      inherit (inputs) nixpkgs-unstable home-manager-unstable home-manager impermanence agenix clank;
      # The CI path replaces the private nixos-secret repo with a stub flake
      # (any path with a secrets/ subdir works: agenix only needs real keys
      # when actually decrypting, which the test DBus-free boot does not do).
      secrets = inputs.secrets;
    };

    testScript = ''
      golem.start()

      golem.wait_for_unit("multi-user.target")

      # Control plane settles (etcd, certs via certmgr, apiserver)
      golem.wait_until_succeeds("gk get nodes | grep -w Ready", timeout=900)

      # agent-sandbox CRDs + controller installed
      golem.wait_until_succeeds(
          "gk get crd sandboxes.agents.x-k8s.io", timeout=300
      )
      golem.wait_until_succeeds(
          "gk -n agent-sandbox-system get deploy agent-sandbox-controller "
          "-o jsonpath='{.status.readyReplicas}' | grep -q 1",
          timeout=300,
      )

      # Addon manager applied the sandbox resources
      golem.wait_until_succeeds(
          "gk -n sandboxes get sandboxtemplate clank", timeout=300
      )
      golem.wait_until_succeeds(
          "gk -n sandboxes get sandboxwarmpool clank", timeout=300
      )

      # The warm pool pre-boots a Kata VM (QEMU-in-QEMU: slow)
      golem.wait_until_succeeds(
          "gk -n sandboxes get pods | grep -E 'clank-.*Running'",
          timeout=1800,
      )

      # The claim is satisfied
      golem.wait_until_succeeds(
          "gk -n sandboxes get sandboxclaim clank -o name", timeout=120
      )

      # Probe inside the MicroVM: the sandbox tmux session exists
      golem.succeed(
          "gk -n sandboxes exec clank-pod -- tmux has-session -t clank"
      )
    '';
  }

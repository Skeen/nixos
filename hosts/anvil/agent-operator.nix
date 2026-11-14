{
  agent-operator,
  pkgs,
  ...
}: let
  built = agent-operator.packages.${pkgs.stdenv.hostPlatform.system};
in {
  # The agent operator (operators/agent-operator, its own repository) has
  # agents work on Issues, custom resources written by hand or by a bridge from
  # a ticketing system, such as the Redmine operator (./redmine-operator.nix).
  # Each open Issue gets a sandbox from the warm pool it names (by default
  # `agent`, see ./agents.nix), whose agent replies into the Issue's status.
  #
  #   sudo k3s kubectl -n agents get issues
  #
  # Deployed like agent-sandbox (./agent-sandbox.nix): its release manifest,
  # with the operator in the agent-operator-system namespace. Its image is
  # loaded into the cluster rather than pulled, as it is not published.
  services.k3s.images = [built.image];
  services.k3s.manifests.agent-operator.source = built.release;
}

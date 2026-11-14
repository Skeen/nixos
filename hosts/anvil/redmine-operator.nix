{
  config,
  lib,
  options,
  pkgs,
  redmine-operator,
  secrets,
  ...
}: let
  built = redmine-operator.packages.${pkgs.stdenv.hostPlatform.system};
in {
  # The Redmine operator (operators/redmine-operator, its own repository)
  # bridges the tickets of Redmine (./redmine.nix) to Issues, which the agent
  # operator (./agent-operator.nix) has agents work on. Every open ticket in
  # the project `ai` assigned to `ai` (AI Bot) becomes an Issue named after it,
  # such as redmine-42. The operator keeps the Issue in step with the ticket,
  # posts the agent's replies on the ticket as notes, and moves the ticket
  # between In Progress and Feedback as the agent works and waits. Closing the
  # ticket, or assigning it to someone else, deletes the Issue, and with it the
  # agent's sandbox.
  #
  #   sudo k3s kubectl -n agents get redmineprojects,issues
  #
  # Deployed like agent-sandbox (./agent-sandbox.nix): its release manifest,
  # with the operator in the redmine-operator-system namespace. Its image is
  # loaded into the cluster rather than pulled, as it is not published.
  config = lib.mkMerge [
    {
      services.k3s.images = [built.image];
      services.k3s.manifests.redmine-operator.source = built.release;

      # The project whose tickets go to agents, in the namespace of ./agents.nix,
      # acting as `ai` with the API key below
      services.k3s.manifests.redmine-projects.content = [
        {
          apiVersion = "agents.internal/v1alpha1";
          kind = "RedmineProject";
          metadata = {
            name = "ai";
            namespace = "agents";
          };
          spec = {
            url = "http://redmine.redmine.svc.cluster.local";
            apiKeySecretRef.name = "redmine-api-key";
            project = "ai";
            inProgressStatus = "In Progress";
            feedbackStatus = "Feedback";
          };
        }
      ];
    }

    # The API key of `ai`, from agenix, as the Secret the RedmineProject refers
    # to. Only where agenix is (anvil, not ./vm-test.nix).
    (lib.optionalAttrs (options ? age) {
      age.secrets.redmine-operator-api-key = {
        file = "${secrets}/secrets/redmine-operator-api-key.age";
        mode = "400";
        owner = "root";
        group = "root";
      };

      systemd.services.redmine-operator-api-key = {
        description = "Give the RedmineProject of the Redmine operator its API key";
        wantedBy = ["multi-user.target"];
        after = ["k3s.service"];
        wants = ["k3s.service"];
        # Again whenever the secret changes
        restartTriggers = [config.age.secrets.redmine-operator-api-key.file];
        path = [config.services.k3s.package];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = "10s";
        };
        # The operator reads it whenever it checks Redmine
        script = ''
          until k3s kubectl get namespace agents > /dev/null 2>&1; do
            sleep 2
          done
          k3s kubectl -n agents create secret generic redmine-api-key \
            --from-file=key=${config.age.secrets.redmine-operator-api-key.path} \
            --dry-run=client --output=yaml |
            k3s kubectl apply -f -
        '';
      };
    })
  ];
}

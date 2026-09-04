{
  config,
  secrets,
  ...
}: {
  # emil's client SSH key, used to fetch the private secrets flake input when
  # rebuilding on golem itself. agenix re-delivers it on every activation, so
  # unlike granary and coffer there is nothing for impermanence to persist:
  # /home/emil lives on the root subvolume that gets rolled back each boot.
  age.secrets.emil-ssh-key = {
    file = "${secrets}/secrets/golem-emil-id_ed25519.age";
    path = "${config.users.users.emil.home}/.ssh/id_ed25519";

    mode = "600";
    owner = "emil";
    group = "users";
  };
}

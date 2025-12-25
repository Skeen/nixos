{
  config,
  secrets,
  ...
}: {
  age.secrets.emil-ssh-key = {
    file = "${secrets}/secrets/stronghold-emil-id_ed25519.age";
    path = "${config.users.users.emil.home}/.ssh/id_rsa";

    mode = "600";
    owner = "emil";
    group = "users";
  };
}

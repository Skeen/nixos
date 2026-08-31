{...}: {
  environment.persistence."/nix/persist" = {
    users.emil = {
      files = [
        ".bash_history"
      ];
    };
  };
}

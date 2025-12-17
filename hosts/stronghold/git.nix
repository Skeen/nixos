{home-manager, ...}: {
  # Git version control system.
  # https://wiki.nixos.org/wiki/Git

  home-manager.users.emil = {
    programs.git = {
      enable = true;
      userName = "Emil Madsen";
      userEmail = "githubpublicemail.goldmine822@passinbox.com";

      extraConfig = {
        # Always run `git pull --rebase`
        # Using `--rebase` stops git from making merge commits when both the local and
        # the remote have advanced at once, instead the local changes are replayed atop
        # the remote changes.
        pull.rebase = true;
      };

      aliases = {
        # Whenever a branch has been rebased or amended `git push` fails as it would
        # override existing commits on the remote, thus `git push --force` must be used
        # to forcefully overwrite the remote to the state of the local repository.
        # `git push --force-with-lease` is a safer alternative to `git push --force`,
        # which verifies that the state of the remote aligns with the local expectation
        # of the state of the remote ensuring that the history on the remote can be
        # overwritten without accidentally overwriting other changes on the remote
        # unexpectedly.
        pushf = "push --force-with-lease";
      };
    };
  };
}

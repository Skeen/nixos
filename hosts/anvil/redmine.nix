{...}: let
  namespace = "redmine";
  labels."app.kubernetes.io/name" = "redmine";

  # The official images, pulled from Docker Hub through the mirror configured
  # in ./k3s.nix. Redmine supports PostgreSQL 14 and up.
  # https://hub.docker.com/_/redmine
  # https://hub.docker.com/_/postgres
  redmineImage = "docker.io/library/redmine:7.0.3";
  postgresImage = "docker.io/library/postgres:18.6";
in {
  # Redmine is a project management web application, here the issue tracker
  # agents take their work from. It runs in the cluster of ./k3s.nix, in a
  # namespace of its own, with its database in the same pod.
  #
  # Browse to http://redmine.localhost on the laptop, and log in as admin with
  # password admin, which Redmine then has changed before anything else. Within
  # the cluster it is http://redmine.redmine.svc.cluster.local.
  #
  # All of its state (the database, attached files and the key sessions are
  # signed with) is on one volume, which the local-path provisioner of k3s keeps
  # in a directory under /var/lib/rancher/k3s/storage.
  # https://www.redmine.org/projects/redmine/wiki/RedmineInstall
  services.k3s.manifests.redmine.content = [
    {
      apiVersion = "v1";
      kind = "Namespace";
      metadata.name = namespace;
    }
    {
      apiVersion = "v1";
      kind = "PersistentVolumeClaim";
      metadata = {
        name = "redmine";
        inherit namespace;
      };
      spec = {
        accessModes = ["ReadWriteOnce"];
        # The local-path provisioner does not enforce the size
        resources.requests.storage = "10Gi";
      };
    }
    {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "redmine";
        inherit namespace labels;
      };
      spec = {
        selector.matchLabels = labels;
        # Stop the old pod before starting a new one, as only one pod can use
        # the volume, and the port on the host, at a time.
        strategy.type = "Recreate";
        template = {
          metadata = {inherit labels;};
          spec = {
            # Kubernetes otherwise announces the `redmine` service to the
            # containers in REDMINE_* variables, where the Redmine image looks
            # for its settings.
            enableServiceLinks = false;
            initContainers = [
              # Rails signs sessions with a secret key. Without one, the image
              # generates a new key for each container it starts, logging
              # everyone out whenever the pod restarts. Generate one once and
              # keep it on the volume instead.
              {
                name = "secret-key-base";
                image = redmineImage;
                command = [
                  "sh"
                  "-c"
                  ''
                    set -e
                    key=/var/lib/redmine/secret_key_base
                    test -s "$key" || ruby -r securerandom -e 'print SecureRandom.hex(64)' > "$key"
                    # The image switches to its redmine user before reading it
                    chown redmine:redmine "$key"
                    chmod 400 "$key"
                  ''
                ];
                volumeMounts = [
                  {
                    name = "data";
                    subPath = "redmine";
                    mountPath = "/var/lib/redmine";
                  }
                ];
              }
              # The database, as a sidecar: started before Redmine, stopped
              # after it. It does not listen on the network at all, only on a
              # socket shared with Redmine. Therefore nothing outside of the pod
              # can connect to it, and it needs no password.
              {
                name = "postgresql";
                image = postgresImage;
                restartPolicy = "Always";
                args = ["-c" "listen_addresses="];
                env = [
                  {
                    name = "POSTGRES_USER";
                    value = "redmine";
                  }
                  {
                    name = "POSTGRES_DB";
                    value = "redmine";
                  }
                  # No password, which the image otherwise insists on
                  {
                    name = "POSTGRES_HOST_AUTH_METHOD";
                    value = "trust";
                  }
                ];
                # When creating the database on its first start, the image runs
                # a temporary server on the same socket, which is not the one
                # to wait for: wait for PostgreSQL itself to be the main process.
                startupProbe = {
                  exec.command = [
                    "sh"
                    "-c"
                    ''[ "$(cat /proc/1/comm)" = postgres ] && pg_isready --host /var/run/postgresql --username redmine''
                  ];
                  periodSeconds = 2;
                  failureThreshold = 150;
                };
                volumeMounts = [
                  {
                    name = "data";
                    subPath = "postgresql";
                    mountPath = "/var/lib/postgresql";
                  }
                  {
                    name = "socket";
                    mountPath = "/var/run/postgresql";
                  }
                ];
              }
            ];
            containers = [
              {
                name = "redmine";
                image = redmineImage;
                env = [
                  # A directory, meaning: connect through the socket in it
                  {
                    name = "REDMINE_DB_POSTGRES";
                    value = "/var/run/postgresql";
                  }
                  {
                    name = "REDMINE_DB_USERNAME";
                    value = "redmine";
                  }
                  {
                    name = "REDMINE_DB_DATABASE";
                    value = "redmine";
                  }
                  {
                    name = "REDMINE_SECRET_KEY_BASE_FILE";
                    value = "/var/lib/redmine/secret_key_base";
                  }
                ];
                ports = [
                  {
                    name = "http";
                    containerPort = 3000;
                    # Publish it on the loopback address of the laptop, where
                    # browsers resolve *.localhost to. Like the rest of the
                    # cluster it is not reachable from the network the laptop
                    # is on.
                    hostIP = "127.0.0.1";
                    hostPort = 80;
                  }
                ];
                readinessProbe.httpGet = {
                  path = "/login";
                  port = "http";
                };
                volumeMounts = [
                  {
                    name = "data";
                    subPath = "files";
                    mountPath = "/usr/src/redmine/files";
                  }
                  {
                    name = "data";
                    subPath = "redmine";
                    mountPath = "/var/lib/redmine";
                    readOnly = true;
                  }
                  {
                    name = "socket";
                    mountPath = "/var/run/postgresql";
                  }
                ];
              }
            ];
            volumes = [
              {
                name = "data";
                persistentVolumeClaim.claimName = "redmine";
              }
              {
                name = "socket";
                emptyDir = {};
              }
            ];
          };
        };
      };
    }
    {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "redmine";
        inherit namespace labels;
      };
      spec = {
        selector = labels;
        ports = [
          {
            name = "http";
            port = 80;
            targetPort = "http";
          }
        ];
      };
    }
  ];
}

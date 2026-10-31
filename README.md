*This project has been created as part of the 42 curriculum by rapoggi.*

# Inception

## Description

Inception is a System Administration project: a small web infrastructure built
with Docker Compose inside a virtual machine. Three services, each in its own
container built from our own Dockerfiles (base image: Alpine 3.23, the
penultimate stable release):

| Service     | Role                                              | Port (internal) |
|-------------|---------------------------------------------------|-----------------|
| `nginx`     | Only entrypoint, HTTPS with TLS 1.2 / 1.3 only    | 443 (published) |
| `wordpress` | WordPress + PHP-FPM (no web server inside)        | 9000            |
| `mariadb`   | MariaDB database (nothing else)                   | 3306            |

Two named volumes persist the data (database and WordPress files) and live on
the host under `/home/rapoggi/data`. All containers share a dedicated bridge
network and restart automatically after a crash.

```
 WWW --443--> [nginx] --9000--> [wordpress] --3306--> [mariadb]
                 \                  |                     |
                  `---- wp_data ----'                  db_data
```

## Instructions

Prerequisites: a Linux VM with Docker, Docker Compose v2, `make` and `openssl`.

```bash
cp srcs/.env.example srcs/.env      # then edit values (login, domain, users)
echo "127.0.0.1 rapoggi.42.fr" | sudo tee -a /etc/hosts
make                                # generates secrets, builds, starts
```

Then open `https://rapoggi.42.fr` (accept the self-signed certificate) and
`https://rapoggi.42.fr/wp-admin` for the administration panel.

| Command        | Effect                                                   |
|----------------|----------------------------------------------------------|
| `make`         | Create missing secrets and data dirs, build, start       |
| `make down`    | Stop and remove containers (data kept)                   |
| `make clean`   | Also remove volumes definitions and built images         |
| `make fclean`  | Also delete `/home/rapoggi/data` (all data lost)         |
| `make re`      | `fclean` then `all`                                      |

See [USER_DOC.md](USER_DOC.md) and [DEV_DOC.md](DEV_DOC.md) for details.

## Project description

### Sources included

- `Makefile`: entry point; wraps `docker compose`.
- `srcs/docker-compose.yml`: services, network, volumes, secrets.
- `srcs/requirements/<service>/`: one `Dockerfile`, `conf/` files, and a
  `tools/main.sh` entrypoint script per service. Each script finishes with
  `exec <daemon>` so the real daemon runs as PID 1 and receives signals.
- `srcs/.env.example`: template for non-secret configuration.

No ready-made service image is pulled: every image is built from `alpine`.

### Design choices

- Alpine for small images; versions pinned (no `latest` tag).
- WordPress is installed and configured at first start with WP-CLI, creating
  an administrator (name without "admin") and a second user.
- mariadb has a healthcheck, and WordPress waits for it to be healthy.
- TLS certificate is self-signed and generated at first start of nginx.

### Virtual Machines vs Docker

A VM virtualizes hardware and runs a full OS kernel per instance: strong
isolation, but heavy (GBs, slow boot). A container shares the host kernel and
isolates only processes, filesystem and network: lightweight, fast to build
and reproducible, with weaker isolation. Here the VM is the host and Docker
splits the stack into single-purpose containers.

### Secrets vs Environment Variables

Environment variables are simple but visible in `docker inspect`, process
environments and logs. Docker secrets are mounted as files in
`/run/secrets/` and only exposed to the services that need them. We use
`.env` for non-sensitive settings (domain, usernames) and secrets for all
passwords. Both are git-ignored.

### Docker Network vs Host Network

With `network_mode: host` a container shares the host's network stack: no
isolation and port conflicts. A user-defined bridge network gives containers
their own network with DNS by service name (`wordpress` reaches `mariadb`),
and only nginx's port 443 is published. Host networking is forbidden here.

### Docker Volumes vs Bind Mounts

Bind mounts map an arbitrary host path into a container and depend on the
host's layout. Named volumes are managed by Docker (portable, listable,
backup-friendly). The subject asks for named volumes whose data is stored in
`/home/rapoggi/data`: they are declared with the `local` driver and
`driver_opts` (`type: none`, `o: bind`, `device: ...`), so they remain Docker
named volumes while their data lands at the required host path.

## Resources

- Docker docs: https://docs.docker.com/ (Compose file reference, secrets,
  volumes, networking, Dockerfile best practices)
- Alpine Linux: https://alpinelinux.org/releases/ and https://wiki.alpinelinux.org/
- NGINX TLS / FastCGI docs: https://nginx.org/en/docs/
- MariaDB knowledge base: https://mariadb.com/kb/
- WordPress / WP-CLI: https://make.wordpress.org/cli/handbook/
- PID 1 and containers: "Docker and the PID 1 zombie reaping problem" articles

**Use of AI:** AI (Claude) was used to review the project against the subject,
and to draft the documentation (README, USER_DOC, DEV_DOC), `.env.example`,
`.dockerignore` files and small Makefile/Dockerfile fixes. All generated
content was reviewed, tested and is understood by the author.

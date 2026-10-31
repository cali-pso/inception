# Developer documentation

## Set up from scratch

Prerequisites (on the VM): Docker Engine, Docker Compose v2 plugin, `make`,
`openssl`, `sudo`.

1. Clone the repository.
2. Create the configuration file:
   ```bash
   cp srcs/.env.example srcs/.env
   ```
   Edit it: `LOGIN`, `DOMAIN_NAME` (`<login>.42.fr`), DB name/user, WordPress
   users. The administrator name must not contain "admin"/"administrator".
3. Secrets: `make` auto-generates missing files in `secrets/`
   (`db_password.txt`, `db_root_password.txt`, `wp_password.txt`,
   `wp_admin_password.txt`). Create them by hand if you prefer chosen values.
   `secrets/` and `srcs/.env` are git-ignored: never commit them.
4. Map the domain: add `127.0.0.1 <login>.42.fr` to `/etc/hosts`.

## Build and launch

```bash
make            # = mkdir data dirs + docker compose -f srcs/docker-compose.yml up -d --build
```

The Makefile exports `LOGIN` (override with `make LOGIN=other`) which
Compose uses for the volume paths. Dockerfiles are built by Compose from
`srcs/requirements/<service>/`.

## Useful commands

```bash
C="docker compose -f srcs/docker-compose.yml"
$C ps                      # status
$C logs -f wordpress       # follow logs
$C exec mariadb mariadb -u root -p   # DB shell (root password in secrets/)
$C up -d --build nginx     # rebuild one service
$C down                    # stop (make down)
docker volume ls           # inception_db_data, inception_wp_data
docker volume inspect inception_db_data
make clean                 # remove containers, volumes definitions, images
make fclean                # + delete /home/<login>/data
```

## Data storage and persistence

| Volume    | Container path    | Host path                        |
|-----------|-------------------|----------------------------------|
| `db_data` | `/var/lib/mysql`  | `/home/<login>/data/mariadb`     |
| `wp_data` | `/var/www/html`   | `/home/<login>/data/wordpress`   |

They are Docker **named volumes** (local driver with `type: none`,
`o: bind`, `device:` pointing at the host path), so data survives
`make down` and reboots. Only `make fclean` / `make re` delete it.

Initialisation is idempotent: the mariadb entrypoint creates the DB/users only
if the data dir is empty; the WordPress entrypoint downloads, configures and
installs WordPress only if not already present.

## Architecture notes

- Network `inception` (bridge): nginx → `wordpress:9000` (FastCGI),
  wordpress → `mariadb:3306`. Only nginx publishes a port (443).
- Each entrypoint ends with `exec <daemon>` (PID 1, no `tail -f`/sleep loops).
- Passwords are read from `/run/secrets/*` at start; non-secret settings come
  from `.env` via `env_file`.

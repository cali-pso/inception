# Developer documentation

How to set the project up from nothing, build it, and work on it.
For everyday use of the running stack, see [USER_DOC.md](USER_DOC.md).

## Setting up from scratch

### 1. Prerequisites

On the virtual machine (Debian or Ubuntu):

- Docker Engine and the Docker Compose v2 plugin, which provides `docker compose`
  as a subcommand rather than the old `docker-compose` binary
- `make`, `git`, `openssl` and `sudo`
- Your user added to the `docker` group, so Docker can run without `sudo`
- Around 10 GB of free disk, more if you pull a larger language model

Outbound internet access is needed during the build: Alpine packages, WP-CLI,
Adminer, WordPress itself and the Redis plugin are all downloaded.

### 2. Configuration

```bash
git clone <repository> && cd inception
cp srcs/.env.example srcs/.env
```

Then edit `srcs/.env`. It holds non-secret values only:

| Variable | Meaning |
|---|---|
| `LOGIN` | Your 42 login. Decides the data path `/home/<LOGIN>/data` |
| `DOMAIN_NAME` | `${LOGIN}.42.fr`; used for the TLS certificate and the WordPress URL |
| `MYSQL_DATABASE`, `MYSQL_USER` | The database and the application account |
| `WP_TITLE` | The site title |
| `WP_ADMIN_USER`, `WP_ADMIN_EMAIL` | The administrator. The name must **not** contain `admin` or `administrator` |
| `WP_USER`, `WP_USER_EMAIL` | The second, non-administrator account |
| `FTP_USER` | The FTP login name |
| `FTP_PASV_ADDRESS` | The address FTP clients connect back to. `127.0.0.1` when connecting from the VM itself |
| `OLLAMA_MODEL` | The model `make pull-model` downloads, e.g. `qwen2.5:0.5b` |

`LOGIN` is read from this one file by both Compose (for the volume paths) and the
Makefile (for the data directories), so it is defined in exactly one place.

### 3. Secrets

Five password files live in `secrets/`:

```
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_password.txt
secrets/wp_admin_password.txt
secrets/ftp_password.txt
```

`make` generates any that are missing with `openssl rand -base64 18` and never
overwrites an existing one, so you can write your own values beforehand if you prefer.
Both `srcs/.env` and `secrets/` are listed in `.gitignore` and must never be committed.

### 4. The domain

Add the domain to the host's resolver:

```bash
echo "127.0.0.1 ${LOGIN}.42.fr" | sudo tee -a /etc/hosts
```

### 5. Build and launch

```bash
make
```

That runs the `secrets` target, creates `/home/<login>/data/{mariadb,wordpress,site,ollama}`,
and then `docker compose -f srcs/docker-compose.yml up -d --build`.

Optionally download the language model, which is not part of the image:

```bash
make pull-model
```

## Makefile targets

| Target | What it does |
|---|---|
| `all` (default) | Generate secrets, create the data directories, build and start |
| `secrets` | Create any missing password file; never overwrites |
| `pull-model` | `ollama pull $(OLLAMA_MODEL)` inside the running container |
| `down` | `compose down` — containers removed, volumes and data kept |
| `clean` | `compose down -v --rmi all` — also drops volumes and built images |
| `fclean` | `clean`, then `sudo rm -rf /home/<login>/data` |
| `re` | `fclean` then `all` — a complete rebuild from nothing |

## Working with the containers

```bash
C="docker compose -f srcs/docker-compose.yml"

$C ps                        # status of all nine services
$C logs -f nginx             # follow one service's logs
$C up -d --build wordpress   # rebuild and restart a single service
$C exec wordpress sh         # a shell inside a container
$C restart site              # restart without rebuilding
$C config                    # the fully resolved compose file, after interpolation
```

Useful service-specific commands:

```bash
# WordPress, through WP-CLI
$C exec wordpress wp plugin list --path=/var/www/html --allow-root
$C exec wordpress wp redis status --path=/var/www/html --allow-root

# MariaDB, as root; the password is in secrets/db_root_password.txt
$C exec mariadb mariadb -u root -p

# Redis
$C exec redis redis-cli dbsize
$C exec redis redis-cli info stats | grep keyspace

# Ollama
$C exec ollama ollama list

# NGINX: validate the configuration before restarting
$C exec nginx nginx -t
```

## Working with the volumes

```bash
docker volume ls | grep srcs_
docker volume inspect srcs_wp_data      # shows the device path on the host
```

The volumes are created by Compose and named after the project directory, so they
appear as `srcs_db_data`, `srcs_wp_data`, `srcs_site_data` and `srcs_ollama_data`.

Removing them is deliberate, never accidental: `make down` keeps them, `make clean`
drops the volume definitions and the images, and only `make fclean` deletes the data
on the host.

## Where the data lives and how it persists

| Volume | Mounted at | Host path | Contents |
|---|---|---|---|
| `db_data` | `mariadb:/var/lib/mysql` | `/home/<login>/data/mariadb` | The WordPress database |
| `wp_data` | `wordpress:/var/www/html`, `nginx:/var/www/html` (read-only), `ftp:/srv/ftp/wp_data` | `/home/<login>/data/wordpress` | WordPress core, themes, plugins, uploads |
| `site_data` | `site:/usr/share/site`, `ftp:/srv/ftp/site_data` | `/home/<login>/data/site` | The static showcase site |
| `ollama_data` | `ollama:/models` | `/home/<login>/data/ollama` | Downloaded language models |

These are Docker **named volumes**, not bind mounts. Each is declared with the `local`
driver and `driver_opts` set to `type: none`, `o: bind` and a `device` path, which is
what places their data under `/home/<login>/data` while Docker keeps managing them.

Because the data lives outside the containers, it survives `make down`, a container
crash, a rebuild and a reboot of the virtual machine. The entrypoints are written to
match: each one detects existing data and skips initialisation, so restarting a
container never re-installs or overwrites anything.

## Adding or changing a service

1. Create `srcs/bonus/<name>/` with a `Dockerfile`, a `conf/` directory, and a
   `tools/main.sh` entrypoint if the service needs first-run setup.
2. Add the service to `srcs/docker-compose.yml`: `build.context`, the
   `ALPINE_VERSION` build argument, `image`, `container_name`, `restart: always` and
   `networks: [inception]`.
3. If NGINX must reach it, add a `location` block **and** add the service to NGINX's
   `depends_on`. NGINX resolves every upstream hostname at startup and refuses to
   boot if one cannot be resolved, which would take the whole site down.
4. If it needs persistent state, declare a volume with the same `driver_opts` pattern
   and add its directory to the `mkdir -p` line in the Makefile.
5. If it needs a password, add a secret in `docker-compose.yml` and append the file to
   `SECRETS` in the Makefile so `make` generates it.

### Conventions used throughout

- The entrypoint ends with `exec <daemon>`, so the daemon is PID 1 and receives
  signals. A service with nothing to set up has no script and uses the exec form of
  `ENTRYPOINT` directly.
- Every setup step is guarded so it is safe to repeat, because entrypoints run on
  every container start, not only the first.
- Passwords are read from `/run/secrets/<name>` at runtime. They never appear in a
  Dockerfile, an image layer or the environment.
- Versions are pinned, and the `latest` tag is never used.

## Testing a change

```bash
make re                                  # full rebuild on empty data
$C ps                                    # nine containers Up; mariadb and ollama healthy
curl -kI https://${LOGIN}.42.fr/         # 200
curl -I  http://${LOGIN}.42.fr/          # must fail: port 80 is closed
curl -k  https://${LOGIN}.42.fr/api/ping # PONG
```

Then restart the virtual machine and confirm the site and its content come back
without any manual step.

Two checks worth repeating before a defense, because they are easy to get wrong:

```bash
# only TLS 1.2 and 1.3 are accepted
openssl s_client -connect ${LOGIN}.42.fr:443 -tls1_2   # succeeds
openssl s_client -connect ${LOGIN}.42.fr:443 -tls1_1   # must fail

# a crashed container comes back on its own
docker exec nginx kill -TERM 1 && sleep 3 && $C ps
```

Note that `docker kill` is not a crash test: Docker treats it as a manual stop and the
restart policy deliberately does not apply.

# Developer documentation

How to set the project up from nothing, build it, and work on it.
For everyday use of the running stack, see [USER_DOC.md](USER_DOC.md).

## Setting up from scratch

### 1. Prerequisites

On the virtual machine (Debian or Ubuntu):

- Docker Engine and the Docker Compose v2 plugin, which provides `docker compose` as a
  subcommand rather than the old `docker-compose` binary
- `make`, `git`, `openssl` and `sudo`
- Your user added to the `docker` group, so Docker runs without `sudo`
- Around 10 GB of free disk, more for a larger language model

Outbound internet access is needed during the build: Alpine packages, WP-CLI, Adminer,
WordPress itself and the Redis plugin are all downloaded.

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
`DOMAIN_NAME` uses `${LOGIN}`, which Compose expands when it reads the file.

### 3. Secrets

Five password files live in `secrets/`:

```
secrets/db_password.txt
secrets/db_root_password.txt
secrets/wp_password.txt
secrets/wp_admin_password.txt
secrets/ftp_password.txt
```

`make` generates any that are missing with `openssl rand -base64 18` and never overwrites
an existing one, so you can write your own values beforehand. Both `srcs/.env` and
`secrets/` are in `.gitignore` and must never be committed.

### 4. The domain

`make` adds `127.0.0.1 <domain>` to `/etc/hosts`, which is why it asks for `sudo`. To do
it by hand:

```bash
echo "127.0.0.1 rapoggi.42.fr" | sudo tee -a /etc/hosts
getent hosts rapoggi.42.fr
```

The name is not registered anywhere, so this entry is the only thing that resolves it.
`/etc/nsswitch.conf` lists `hosts: files dns`, so `/etc/hosts` is consulted before any
DNS server. `dig` and `nslookup` bypass it and will keep reporting a failure.

### 5. Build and launch

```bash
make                # secrets, hosts entry, data dirs, build, start
make pull-model     # optional: download the language model
```

## Makefile targets

| Target | What it does |
|---|---|
| `all` (default) | Generate secrets, add the hosts entry, create the data directories, build and start |
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

Service-specific commands:

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

Compose names volumes after the directory holding the compose file, so they appear as
`srcs_db_data`, `srcs_wp_data`, `srcs_site_data` and `srcs_ollama_data`.

Removal is deliberate, never accidental: `make down` keeps them, `make clean` drops the
volume definitions and the images, and only `make fclean` deletes the data on the host.

## Where the data lives and how it persists

| Volume | Mounted at | Host path | Contents |
|---|---|---|---|
| `db_data` | `mariadb:/var/lib/mysql` | `/home/<login>/data/mariadb` | The WordPress database |
| `wp_data` | `wordpress:/var/www/html`, `nginx:/var/www/html` (read-only), `ftp:/srv/ftp/wp_data` | `/home/<login>/data/wordpress` | WordPress core, themes, plugins, uploads |
| `site_data` | `site:/usr/share/site`, `ftp:/srv/ftp/site_data` | `/home/<login>/data/site` | The static showcase site |
| `ollama_data` | `ollama:/models` | `/home/<login>/data/ollama` | Downloaded language models |

These are Docker **named volumes**, not bind mounts. Each is declared with the `local`
driver and `driver_opts` set to `type: none`, `o: bind` and a `device` path, which places
their data under `/home/<login>/data` while Docker keeps managing them.

Because the data lives outside the containers, it survives `make down`, a container
crash, a rebuild and a reboot. The entrypoints are written to match: each detects
existing data and skips initialisation, so restarting never re-installs or overwrites
anything.

## Bonus services

Each bonus is a container of its own under `srcs/bonus/`, with its own Dockerfile.

### redis — object cache

A plain `redis-server` with no entrypoint script: the daemon is the `ENTRYPOINT`, so it
is PID 1 directly. `conf/redis.conf` sets `bind 0.0.0.0` (other containers must reach
it), `save ""` and `appendonly no` (a cache needs no persistence, so no volume), and
`maxmemory 64mb` with `allkeys-lru` so it evicts instead of growing without bound. It is
the only container that does not run as root — the Alpine package creates a `redis` user
and the Dockerfile switches to it.

The WordPress side is driven from `wordpress/tools/main.sh`, which sets `WP_REDIS_HOST`,
`WP_REDIS_PORT` and `WP_REDIS_GRACEFUL` in `wp-config.php`, installs the Redis Object
Cache plugin and runs `wp redis enable` to place the `object-cache.php` drop-in.

`WP_REDIS_GRACEFUL` matters: without it, the drop-in throws and the whole site returns
an error page whenever Redis is unreachable, which would mean an optional bonus could
take the mandatory part down.

The plugin install is deliberately non-fatal (`|| echo warning`), so a failed download
cannot put WordPress into a restart loop. The trade-off is that the stack can come up
with no cache at all and only a line in the logs, so check `wp redis status` after any
rebuild on a machine with flaky networking.

### ftp — write access to the web volumes

vsftpd, chrooted to `/srv/ftp`, with the two volumes mounted inside it as `wp_data` and
`site_data`. The entrypoint creates the user with `-u 82 -G www-data`, the same uid that
owns the web files, so uploads need no permission fixing; the password is read from the
Docker secret and applied with `chpasswd` at start, never baked into the image.

FTP needs a second connection for data. Passive mode is used, because the client cannot
reach back into the Docker network, which is why ports 21000-21010 are published and why
`pasv_address` is written from `FTP_PASV_ADDRESS` at startup.

### adminer — database manager

A single PHP file behind php-fpm, with no web server in the container. NGINX reaches it
over FastCGI with an exact-match location, and passes `SCRIPT_FILENAME` as a path inside
the Adminer container, so no volume is shared between them. The pool runs as `nobody`
because Adminer never writes anything.

### site — the static showcase

A second, minimal NGINX serving plain HTML and CSS. The image carries the pages under
`/usr/share/site-default/`, and the entrypoint copies them into the volume **only when
the volume is empty**; otherwise the volume wins. This is what makes the page replaceable
over FTP without rebuilding, while a fresh clone still starts with content.

The main NGINX proxies `/site/` to it over HTTP, with a trailing slash on `proxy_pass` so
the `/site/` prefix is stripped before the request reaches the static server.

### ollama + chat — the free-choice service

`ollama` runs the model server. It is not routed by NGINX at all: only `chat` can reach
it. Models live in `ollama_data` and are fetched with `make pull-model`, never at build
or at container start, since a background pull would break the no-daemon-hacks rule and
baking a model in would bloat the image.

`chat` is a Flask app served by gunicorn, which supervises its workers and handles
signals properly; the gunicorn master is PID 1. It exposes `/api/ping` and `/api/chat`
internally, and NGINX maps the public `/chat/` prefix onto them.

Three timeouts are involved and must stay nested, each larger than the one inside it:

```
requests.post(..., timeout=120)  <  gunicorn --timeout 180  <  nginx proxy_read_timeout 300s
```

If the outer one is smaller, NGINX cuts the request off with a 504 while the backend is
still working, and the answer is thrown away.

### Adding another bonus service

1. Create `srcs/bonus/<name>/` with a `Dockerfile`, a `conf/` directory, and a
   `tools/main.sh` entrypoint only if the service needs first-run setup.
2. Add the service to `srcs/docker-compose.yml`: `build.context`, the `ALPINE_VERSION`
   build argument, `image`, `container_name`, `restart: always` and
   `networks: [inception]`.
3. If NGINX must reach it, add a `location` block **and** add the service to NGINX's
   `depends_on`. NGINX resolves every upstream hostname at startup and refuses to boot if
   one cannot be resolved, which would take the whole site down.
4. If it needs persistent state, declare a volume with the same `driver_opts` pattern and
   add its directory to the `mkdir -p` line in the Makefile.
5. If it needs a password, add a secret in `docker-compose.yml` and append the file to
   `SECRETS` in the Makefile so `make` generates it.
6. Add a `.dockerignore` so the build context stays small.

### Conventions used throughout

- The entrypoint ends with `exec <daemon>`, so the daemon is PID 1 and receives signals.
  A service with nothing to set up has no script and uses the exec form of `ENTRYPOINT`.
- Every setup step is guarded so it is safe to repeat, because entrypoints run on every
  container start, not only the first.
- Passwords are read from `/run/secrets/<name>` at runtime. They never appear in a
  Dockerfile, an image layer or the environment.
- Versions are pinned, and the `latest` tag is never used.

## NGINX routing, and the two traps

```nginx
location = /adminer.php { fastcgi_pass adminer:9000; }   # exact match, highest priority
location ~ \.php$       { fastcgi_pass wordpress:9000; } # regex
location ^~ /site/      { proxy_pass http://site:80/; }  # prefix, skips the regex stage
location ^~ /chat/      { proxy_pass http://chat:5000/api/; }
location /              { try_files $uri $uri/ /index.php?$args; }
```

**`^~` is not decoration.** NGINX checks an exact `=` match first, then the longest
prefix match, then regexes in file order. A plain prefix match loses to a regex, so
without `^~` a request for `/site/anything.php` would match `\.php$` and be sent to
WordPress. `^~` means "longest prefix wins, stop before the regex stage".

**The trailing slash on `proxy_pass` decides whether the prefix is stripped.**

| `proxy_pass` | Request | Backend receives |
|---|---|---|
| `http://chat:5000` | `/chat/ping` | `/chat/ping` — unchanged |
| `http://chat:5000/` | `/chat/ping` | `/ping` — prefix stripped |
| `http://chat:5000/api/` | `/chat/ping` | `/api/ping` — prefix replaced |

The Flask app serves `/api/ping` and `/api/chat`, so the third form is the one that
matches. The first two produce a 404 from Flask, not from NGINX, which makes it easy to
misdiagnose.

## Testing a change

```bash
make re                                   # full rebuild on empty data
$C ps                                     # nine containers Up; mariadb and ollama healthy
curl -kI https://${LOGIN}.42.fr/          # 200
curl -I  http://${LOGIN}.42.fr/           # must fail: port 80 is closed
curl -k  https://${LOGIN}.42.fr/chat/ping # PONG
curl -kI https://${LOGIN}.42.fr/site/     # 200
```

Then restart the virtual machine and confirm the site and its content come back with no
manual step.

Two checks worth repeating before a defense, because they are easy to get wrong:

```bash
# only TLS 1.2 and 1.3 are accepted
openssl s_client -connect ${LOGIN}.42.fr:443 -tls1_2   # succeeds
openssl s_client -connect ${LOGIN}.42.fr:443 -tls1_1   # must fail

# a crashed container comes back on its own
docker exec nginx kill -TERM 1 && sleep 3 && $C ps
```

`docker kill` is **not** a crash test: Docker treats it as a manual stop and the restart
policy deliberately does not apply. Send a signal to PID 1 from inside the container
instead.

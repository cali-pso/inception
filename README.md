*This project has been created as part of the 42 curriculum by rapoggi.*

# Inception

## Description

Inception is a System Administration project: a small web infrastructure built with
Docker Compose inside a virtual machine. Every image is written from scratch — no
ready-made image is pulled from Docker Hub — and each service runs in its own
container on a pinned Alpine Linux base (`3.23`, the penultimate stable release).

NGINX is the only way into the web services, over HTTPS with TLS 1.2 / 1.3 only. It
serves a WordPress site backed by MariaDB, and forwards the other paths to the bonus
services. The bonus FTP server is the one other published port.

### Mandatory services

| Service | Role | Internal port |
|---|---|---|
| `nginx` | TLS termination and single web entry point | 443 (published) |
| `wordpress` | WordPress + php-fpm, no web server of its own | 9000 |
| `mariadb` | The WordPress database | 3306 |

### Bonus services

| Service | Role | Internal port |
|---|---|---|
| `redis` | Persistent object cache for WordPress | 6379 |
| `ftp` | vsftpd, write access to the WordPress and site volumes | 21, 21000-21010 (published) |
| `adminer` | Single-file database manager | 9000 |
| `site` | Static showcase site describing this stack | 80 |
| `ollama` | Local language-model server, never routed publicly | 11434 |
| `chat` | Flask API in front of Ollama, run under gunicorn | 5000 |

### Routing

| Path | Goes to | How |
|---|---|---|
| `/` | wordpress | FastCGI to `wordpress:9000` |
| `/wp-admin/` | wordpress | WordPress administration panel |
| `/adminer.php` | adminer | FastCGI to `adminer:9000` |
| `/site/` | site | HTTP proxy to `site:80` |
| `/chat/` | chat | HTTP proxy to `chat:5000` |

## Instructions

Prerequisites on the VM: Docker Engine, the Docker Compose v2 plugin, `make`,
`openssl` and `sudo`.

```bash
cp srcs/.env.example srcs/.env          # then edit LOGIN, the users, the model
make                                     # secrets, data dirs, hosts entry, build, start
make pull-model                          # download the language model
```

Then open `https://rapoggi.42.fr`. The certificate is self-signed, so the browser
warning is expected.

| Command | Effect |
|---|---|
| `make` | Create secrets and data directories, add the hosts entry, build and start |
| `make pull-model` | Pull `OLLAMA_MODEL` into the Ollama volume |
| `make down` | Stop and remove the containers, keeping all data |
| `make clean` | Also remove the volumes and the built images |
| `make fclean` | Also delete `/home/<login>/data` — all data is lost |
| `make re` | `fclean` followed by a full rebuild |

See [USER_DOC.md](USER_DOC.md) for day-to-day use and [DEV_DOC.md](DEV_DOC.md) for
setting the project up from scratch.

## Bonus part

The subject lists five bonus items. All five are implemented, each as its own service
with its own Dockerfile, and each with a dedicated volume where it needs one.

| Subject requirement | Implemented as | Notes |
|---|---|---|
| Redis cache for the WordPress site | `redis` | The Redis Object Cache drop-in makes WordPress's object cache persistent between requests |
| FTP server pointing to the WordPress volume | `ftp` | vsftpd, chrooted, also exposes the static-site volume |
| A static website in a language other than PHP | `site` | Hand-written HTML and CSS, no PHP and no JavaScript, served by a minimal second NGINX |
| Adminer | `adminer` | Single PHP file behind php-fpm, reached over FastCGI |
| A service of your choice | `ollama` + `chat` | A local language model with a small HTTP API in front of it |

### Why Ollama and a Flask API for the free-choice service

The free-choice bonus has to be justified at the defense, so the reasoning is recorded
here.

**What it is.** `ollama` runs a small language model entirely on the VM's CPU. `chat`
is a Flask application, served by gunicorn, that accepts a message and returns the
model's answer.

**Why it is useful.** Everything stays on the machine. No prompt, and no data the
prompt contains, is ever sent to a third party. That is a real difference from calling
a hosted API, and it is the reason to run a model locally at all.

**Why two containers rather than one.** The subject requires one service per
container, and the split is also what makes the design defensible: Ollama's own API can
pull, delete and replace models, so exposing it publicly would let anyone fill the disk
or swap the model. `ollama` is therefore reachable only from `chat`, and `chat` exposes
exactly two endpoints. NGINX never talks to Ollama directly.

**Why the model is not downloaded at build or start.** Pulling a model at container
start would need a background process, which the subject forbids, and baking it into the
image would make the image enormous and the build non-reproducible. Instead the models
live in their own volume and are fetched on demand with `make pull-model`.

**Why gunicorn and not the Flask development server.** The Flask server is explicitly
not for production: it is single-process, it has no supervision, and it handles signals
poorly. Gunicorn runs a master process that supervises its workers, restarts one that
dies or hangs, and shuts down cleanly on SIGTERM. The master is PID 1 in the container,
exactly like `nginx` or `mariadbd` in the other services.

### Bonus design notes

- **Redis fails soft.** `WP_REDIS_GRACEFUL` is set, so if Redis is unreachable the site
  still serves pages instead of showing a Redis connection error. Verified by stopping
  the container while the site was under load.
- **FTP shares the volumes rather than copying.** The FTP user is uid 82, the same uid
  that owns the WordPress and site files, so uploads are usable immediately with no
  permission fixing and no restart.
- **The static site is seeded, not baked.** The image carries a default copy of the
  pages, and the entrypoint copies it into the volume only when the volume is empty.
  After that the volume wins, so pages can be replaced over FTP without a rebuild.
- **Adminer has no web server.** Like WordPress it is pure PHP behind php-fpm, which is
  why NGINX reaches it over FastCGI rather than HTTP.

## Project description

### Use of Docker and the sources in this repository

The project is driven entirely by the `Makefile` at the root, which is a thin wrapper
around `docker compose`. Compose builds nine images from nine of our own Dockerfiles,
creates one user-defined bridge network, four named volumes and five secrets, and starts
the containers in dependency order.

```
.
├── Makefile                  entry point: build, start, stop, clean
├── srcs/
│   ├── docker-compose.yml    services, network, volumes, secrets
│   ├── .env.example          template for the non-secret configuration
│   ├── requirements/         the three mandatory services
│   │   ├── nginx/{Dockerfile,conf/,tools/}
│   │   ├── wordpress/{Dockerfile,conf/,tools/}
│   │   └── mariadb/{Dockerfile,conf/,tools/}
│   └── bonus/                the six bonus containers
│       ├── redis/   ftp/   adminer/
│       └── site/    ollama/ chat/
└── secrets/                  git-ignored, generated by `make`
```

Each service directory holds a `Dockerfile`, its configuration under `conf/`, and, where
first-run setup is needed, an entrypoint script under `tools/`.

### Main design choices

- **The daemon is PID 1.** Every entrypoint script ends with `exec <daemon>`, so the real
  process receives signals directly. No `tail -f`, no `sleep infinity`, no background
  process. Services that need no setup (`redis`, `adminer`, `ollama`, `chat`) have no
  script at all and use the exec form of `ENTRYPOINT` instead.
- **Initialisation is idempotent.** Entrypoints run on every start, so each step is
  guarded: MariaDB only bootstraps when its data directory is empty, WordPress only
  installs when it is not already present, and the FTP user is only created once.
- **Versions are pinned.** The Alpine version is a build argument, and WP-CLI and Adminer
  are fetched at fixed releases. The `latest` tag is never used.
- **Startup order is explicit.** WordPress waits for MariaDB to report healthy, `chat`
  waits for Ollama, and NGINX waits for every backend it proxies to, because it resolves
  upstream hostnames at startup and refuses to boot if one cannot be resolved.
- **Only two ports are published.** 443 for NGINX, and FTP's control and passive ports.
  Everything else is reachable only inside the Docker network.

### Virtual Machines vs Docker

A virtual machine virtualizes hardware and runs a complete operating system with its own
kernel. Isolation is strong, but each instance costs gigabytes of disk and memory and
takes a long time to boot. A container shares the host kernel and isolates only
processes, filesystem and network, through namespaces and cgroups. It is far lighter,
starts in milliseconds and is reproducible from a Dockerfile, at the cost of weaker
isolation: a kernel vulnerability is shared by every container on the host.

Here the virtual machine is the host, and Docker splits the stack into single-purpose
containers inside it. That is the point of the project: one process per container, each
rebuildable and replaceable on its own.

### Secrets vs Environment Variables

Environment variables are convenient but leak easily. They are visible to anyone who can
run `docker inspect`, they are inherited by every child process, and they are routinely
printed in logs and crash reports.

Docker secrets are mounted read-only as files under `/run/secrets/` inside only the
containers that declare them. They never appear in the image, in the container's
environment, or in `docker inspect`.

This project uses `.env` for non-sensitive configuration only — domain name, database
name, usernames, model name — and Docker secrets for all five passwords. Both `.env` and
`secrets/` are git-ignored, so no credential is ever committed.

### Docker Network vs Host Network

With `network_mode: host` a container shares the host's network stack: it has no network
isolation at all, every listening port is immediately reachable on the host, and two
containers cannot bind the same port. The subject forbids it.

A user-defined bridge network gives the containers their own private network with an
embedded DNS server, so a container reaches another by its service name — `wordpress`
connects to `mariadb`, `chat` connects to `ollama`. Nothing is reachable from the host
unless it is explicitly published, which is why only NGINX and FTP appear there.

### Docker Volumes vs Bind Mounts

A bind mount maps an arbitrary host path into a container. It depends on the host's
directory layout and permissions, and Docker neither creates nor tracks it.

A named volume is created and managed by Docker: it is listed by `docker volume ls`,
inspected, backed up and removed through Docker, and it is not tied to a specific host
path.

The subject asks for named volumes whose data nevertheless ends up in
`/home/<login>/data`. The four volumes are therefore declared with the `local` driver and
`driver_opts` (`type: none`, `o: bind`, `device: /home/<login>/data/...`). They remain
Docker named volumes — Compose creates them, `docker volume ls` shows them, and
`make clean` removes them — while their contents live at the required host path.

## Resources

- Docker documentation — Compose file reference, secrets, volumes, networking and
  Dockerfile best practices: <https://docs.docker.com/>
- Alpine Linux — releases and package search: <https://alpinelinux.org/releases/> and
  <https://pkgs.alpinelinux.org/packages>
- NGINX — TLS configuration, `location` matching, FastCGI and proxying:
  <https://nginx.org/en/docs/>
- MariaDB Knowledge Base — `mariadb-install-db` and user privileges: <https://mariadb.com/kb/>
- WP-CLI handbook — `core install`, `config set`, `plugin install`:
  <https://make.wordpress.org/cli/handbook/>
- Redis Object Cache plugin: <https://wordpress.org/plugins/redis-cache/>
- vsftpd manual page — chroot and passive mode: <https://security.appspot.com/vsftpd.html>
- Gunicorn documentation — workers, threads and timeouts: <https://docs.gunicorn.org/>
- Ollama API reference: <https://github.com/ollama/ollama/blob/main/docs/api.md>
- PID 1 and signal handling in containers, and why an entrypoint should `exec` its daemon.

### Use of AI

AI (Claude) was used as a reviewer and as a documentation assistant, not as a code
generator for the services themselves:

- **Reviewing the project against the subject.** It built and ran the stack repeatedly,
  checking the accepted TLS versions, the published ports, PID 1 in each container, the
  volume configuration, restart behaviour and data persistence, and reported what did not
  match.
- **Finding concrete bugs**, among others: a missing `^~` that sent `/site/*.php` to
  WordPress; an inverted timeout chain where NGINX cut `/chat/` requests off at 60s; a
  missing `depends_on` that made NGINX crash-loop whenever a bonus container was absent;
  a missing `php83-opcache` that was costing roughly a fivefold drop in throughput; and a
  `proxy_pass` trailing-slash mismatch that made every `/chat/` endpoint return 404.
- **Writing the documentation** — this README, `USER_DOC.md` and `DEV_DOC.md` — and the
  HTML and CSS of the static showcase site.
- **Explaining concepts** while the services were being written: `location` matching,
  FastCGI versus HTTP proxying, passive-mode FTP, gunicorn versus the Flask development
  server, and how name resolution uses `/etc/hosts` before DNS.

Every suggestion was tested on the project before being kept, and the author can explain
each line of the result.

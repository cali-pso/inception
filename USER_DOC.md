# User documentation

This file is for someone who needs to run and use the stack, not to modify it.
Developers should read [DEV_DOC.md](DEV_DOC.md) instead.

Replace `rapoggi` with the login configured in `srcs/.env` everywhere on this page.

## What the stack provides

| What you get | Where | Notes |
|---|---|---|
| A WordPress website | `https://rapoggi.42.fr` | HTTPS only, self-signed certificate |
| The WordPress admin panel | `https://rapoggi.42.fr/wp-admin` | Two accounts: an administrator and an author |
| A database manager | `https://rapoggi.42.fr/adminer.php` | Browse tables, run queries, export data |
| A static showcase site | `https://rapoggi.42.fr/site/` | Describes every service in the stack |
| A chat API backed by a local AI model | `https://rapoggi.42.fr/chat/chat` | Runs on this machine; no prompt leaves the VM |
| FTP access to the web files | `ftp://127.0.0.1` | Edit site content without rebuilding anything |

Behind these, three more services work invisibly: MariaDB stores the WordPress data,
Redis caches database queries to make pages faster, and Ollama runs the language model.

## Starting and stopping

Run everything from the root of the repository.

```bash
make            # build if needed, then start everything in the background
make down       # stop and remove the containers; all data is kept
```

The first start takes a few minutes: images are built, WordPress is downloaded and
installed, and the TLS certificate is generated. Afterwards, startup takes seconds.

`make` also adds `rapoggi.42.fr` to `/etc/hosts`, which needs `sudo`, so it may ask for
your password.

The containers restart automatically if they crash, and come back on their own after the
virtual machine reboots.

```bash
make re         # DESTRUCTIVE: erase all data and rebuild from scratch
```

## Reaching the website

1. The domain must resolve to this machine. `make` adds the entry, but you can check it:

   ```bash
   getent hosts rapoggi.42.fr        # expect: 127.0.0.1 rapoggi.42.fr
   ```

   `rapoggi.42.fr` is not a real registered domain, so without this line nothing can
   resolve it. Note that `dig` and `nslookup` query DNS directly and ignore
   `/etc/hosts`, so they will report a failure even when everything works.

2. Open `https://rapoggi.42.fr`. The certificate is self-signed, so the browser warns
   the first time; accept it to continue.
3. Log in at `https://rapoggi.42.fr/wp-admin`. The username is `WP_ADMIN_USER` from
   `srcs/.env`, and the password is in `secrets/wp_admin_password.txt`.

Plain HTTP is not served at all: port 80 is closed, and only 443 is open.

## Bonus features

Five bonus services are included. Here is how to use each one.

### Faster pages with Redis

Nothing to do: it works by itself. Redis stores the results of WordPress's database
queries so repeated page loads do not hit MariaDB again. If Redis stops, the site keeps
working and simply becomes slower.

To see that the cache is doing something, load a few pages and then:

```bash
docker compose -f srcs/docker-compose.yml exec redis redis-cli dbsize
docker compose -f srcs/docker-compose.yml exec redis redis-cli info stats | grep keyspace
```

`keyspace_hits` should climb as you browse.

### The database manager, Adminer

Open `https://rapoggi.42.fr/adminer.php` and fill the form in with:

| Field | Value |
|---|---|
| System | MySQL |
| Server | `mariadb` |
| Username | the value of `MYSQL_USER` in `srcs/.env` |
| Password | the contents of `secrets/db_password.txt` |
| Database | the value of `MYSQL_DATABASE` |

Logging in as `root` is refused on purpose: the root account exists only on `localhost`
inside the database container and cannot be reached across the network.

### The static showcase site

`https://rapoggi.42.fr/site/` is a plain HTML page describing the whole stack: the
services, the routing, the volumes and the commands. It is a good starting point for
anyone seeing the project for the first time.

### FTP access

FTP gives read and write access to the WordPress files and to the static site, so content
can be changed without rebuilding an image.

```bash
ftp 127.0.0.1
# username: the value of FTP_USER in srcs/.env
# password: the contents of secrets/ftp_password.txt
```

After logging in there are two directories:

- `wp_data` — the WordPress installation, including `wp-content/uploads`
- `site_data` — the static showcase site

Files uploaded there appear on the website immediately, with no restart. Use a client in
passive mode, which is the default almost everywhere. If a listing hangs forever, the
client is in active mode; switch it to passive.

### The AI chat API

The API takes a form field named `message` and answers in plain text.

```bash
curl -k https://rapoggi.42.fr/chat/ping        # liveness check, answers PONG

curl -k -X POST https://rapoggi.42.fr/chat/chat \
  -d 'message=Explain Docker volumes in one sentence'
```

The model must be downloaded once before the first question:

```bash
make pull-model
```

The model runs on the CPU, so a short answer takes a few seconds. The very first request
after a restart is slower, while the model is loaded into memory, and requests are
answered one at a time. Nothing is sent off the machine.

## Credentials

| What | Where |
|---|---|
| Usernames, domain, database name, model name | `srcs/.env` |
| WordPress administrator password | `secrets/wp_admin_password.txt` |
| WordPress author password | `secrets/wp_password.txt` |
| Database user password | `secrets/db_password.txt` |
| Database root password | `secrets/db_root_password.txt` |
| FTP password | `secrets/ftp_password.txt` |

Both `srcs/.env` and the whole `secrets/` directory are excluded from Git and are never
committed. `make` creates any missing secret file with a random password and never
overwrites one that already exists.

To read a password:

```bash
cat secrets/wp_admin_password.txt
```

To change one:

- **WordPress accounts** — change them from the admin panel. This keeps all content.
- **Database or FTP** — edit the file in `secrets/`, then run `make re`. These passwords
  are applied when the service first initialises, so a full reset is needed, and
  `make re` deletes all data.

## Checking that everything runs

```bash
docker compose -f srcs/docker-compose.yml ps
```

All nine containers should be `Up`, and `mariadb` and `ollama` should also say `healthy`.

```bash
curl -kI https://rapoggi.42.fr              # the website answers: 200
curl -I  http://rapoggi.42.fr               # must fail: port 80 is closed
curl -k  https://rapoggi.42.fr/chat/ping    # PONG
curl -kI https://rapoggi.42.fr/site/        # 200
curl -kI https://rapoggi.42.fr/adminer.php  # 200
```

To read the logs of one service:

```bash
docker compose -f srcs/docker-compose.yml logs -f wordpress
```

## If something is wrong

| Symptom | What to check |
|---|---|
| The browser cannot find the site | `getent hosts rapoggi.42.fr`, and that `nginx` is `Up` |
| The site shows a database error | Is `mariadb` healthy in `docker compose ps`? |
| A container keeps restarting | Its logs: `docker compose -f srcs/docker-compose.yml logs <service>` |
| The chat API returns 500 | Is `ollama` `Up`, and has `make pull-model` been run? |
| FTP connects but listing hangs | The client is in active mode; switch it to passive |
| Pages are slow and Redis looks empty | The cache plugin may have failed to install; see `docker compose logs wordpress` |

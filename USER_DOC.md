# User documentation

This file is for someone who needs to run and use the stack, not to modify it.
Developers should read [DEV_DOC.md](DEV_DOC.md) instead.

## What the stack provides

| What you get | Where | Notes |
|---|---|---|
| A WordPress website | `https://rapoggi.42.fr` | HTTPS only, self-signed certificate |
| The WordPress admin panel | `https://rapoggi.42.fr/wp-admin` | Two accounts: an administrator and an author |
| A database manager | `https://rapoggi.42.fr/adminer.php` | Browse tables, run queries, export data |
| A static showcase site | `https://rapoggi.42.fr/site/` | Describes every service in the stack |
| A chat API backed by a local AI model | `https://rapoggi.42.fr/api/chat` | Runs on the machine; no prompt leaves the VM |
| FTP access to the web files | `ftp://127.0.0.1` | Edit site content without rebuilding anything |

Behind these, three more services do their work invisibly: MariaDB stores the
WordPress data, Redis caches database queries to speed the site up, and Ollama runs
the language model.

Replace `rapoggi` with the login configured in `srcs/.env` everywhere on this page.

## Starting and stopping

Run everything from the root of the repository.

```bash
make            # build if needed, then start everything in the background
make down       # stop and remove the containers; all data is kept
```

The first start takes a few minutes: the images are built, WordPress is downloaded
and installed, and the TLS certificate is generated. Afterwards, startup is quick.

The containers restart automatically if they crash, and they come back on their own
after the virtual machine reboots.

```bash
make re         # DESTRUCTIVE: erase all data and rebuild from scratch
```

## Reaching the website

1. The domain must point at the machine. Check that `/etc/hosts` contains:

   ```
   127.0.0.1 rapoggi.42.fr
   ```

2. Open `https://rapoggi.42.fr`. The certificate is self-signed, so the browser shows
   a warning the first time; accept it to continue.
3. Log in at `https://rapoggi.42.fr/wp-admin` with the administrator account. The
   username is `WP_ADMIN_USER` in `srcs/.env`, and the password is in
   `secrets/wp_admin_password.txt`.

Plain HTTP is not served at all: port 80 is closed, and only 443 is open.

## Using the AI chat API

The API takes a form field named `message` and answers in plain text.

```bash
curl -k https://rapoggi.42.fr/api/ping          # liveness check, answers PONG

curl -k -X POST https://rapoggi.42.fr/api/chat \
  -d 'message=Explain Docker volumes in one sentence'
```

The model must be downloaded once before the first question:

```bash
make pull-model
```

The model runs on the CPU, so an answer takes a few seconds, and the very first
request after a restart is slower while the model is loaded into memory. Requests are
answered one at a time.

## Using FTP

FTP gives read and write access to the WordPress files and to the static site, so
content can be changed without rebuilding an image.

```bash
ftp 127.0.0.1
# username: the value of FTP_USER in srcs/.env
# password: the contents of secrets/ftp_password.txt
```

After logging in there are two directories:

- `wp_data` — the WordPress installation, including `wp-content/uploads`
- `site_data` — the static showcase site

Files uploaded there are visible on the website immediately, with no restart. Use a
client that supports passive mode, which is the default almost everywhere.

## Credentials

| What | Where |
|---|---|
| Usernames, domain, database name, model name | `srcs/.env` |
| WordPress administrator password | `secrets/wp_admin_password.txt` |
| WordPress author password | `secrets/wp_password.txt` |
| Database user password | `secrets/db_password.txt` |
| Database root password | `secrets/db_root_password.txt` |
| FTP password | `secrets/ftp_password.txt` |

Both `srcs/.env` and the whole `secrets/` directory are excluded from Git and are
never committed. `make` creates any missing secret file with a random password and
never overwrites one that already exists.

To change a password:

- **WordPress accounts** — change them from the admin panel. This keeps all content.
- **Database or FTP** — edit the file in `secrets/`, then run `make re`. These
  passwords are applied when the service first initialises, so a full reset is needed;
  `make re` deletes all data.

To read a password:

```bash
cat secrets/wp_admin_password.txt
```

## Checking that everything runs

```bash
docker compose -f srcs/docker-compose.yml ps
```

All nine containers should be `Up`, and `mariadb` and `ollama` should also say
`healthy`.

```bash
# the website answers
curl -kI https://rapoggi.42.fr

# port 80 is closed, as intended
curl -I http://rapoggi.42.fr

# the API is alive
curl -k https://rapoggi.42.fr/api/ping

# the cache is connected
docker compose -f srcs/docker-compose.yml exec wordpress \
  wp redis status --path=/var/www/html --allow-root
```

To read the logs of one service:

```bash
docker compose -f srcs/docker-compose.yml logs -f wordpress
```

## If something is wrong

| Symptom | What to check |
|---|---|
| The browser cannot find the site | The `/etc/hosts` entry, and that `nginx` is `Up` |
| The site shows a database error | `docker compose -f srcs/docker-compose.yml ps` — is `mariadb` healthy? |
| A container keeps restarting | Its logs: `docker compose -f srcs/docker-compose.yml logs <service>` |
| The chat API returns 500 | Is `ollama` `Up`, and has `make pull-model` been run? |
| FTP connects but listing hangs | The client is in active mode; switch it to passive |

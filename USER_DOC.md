# User documentation

## Services provided

- **Website** (WordPress) served over HTTPS at `https://rapoggi.42.fr`.
- **Administration panel** at `https://rapoggi.42.fr/wp-admin`.
- Behind the scenes: nginx (HTTPS entrypoint), PHP-FPM running WordPress, and
  a MariaDB database. Only port 443 is reachable from outside.

## Start and stop

From the repository root:

```bash
make          # build (first time) and start everything
make down     # stop and remove containers; data is kept
make re       # DESTRUCTIVE: wipe all data and rebuild from scratch
```

Containers restart automatically if they crash.

## Access the website and admin panel

1. Make sure `/etc/hosts` contains `127.0.0.1 rapoggi.42.fr`.
2. Browse to `https://rapoggi.42.fr`. The certificate is self-signed, so
   accept the browser warning.
3. Log in at `https://rapoggi.42.fr/wp-admin` with the administrator account
   (username: `WP_ADMIN_USER` in `srcs/.env`, password: see below).

## Credentials

| What                         | Where                                  |
|------------------------------|----------------------------------------|
| Usernames, domain, DB name   | `srcs/.env`                            |
| WordPress admin password     | `secrets/wp_admin_password.txt`        |
| WordPress user password      | `secrets/wp_password.txt`              |
| Database user password       | `secrets/db_password.txt`              |
| Database root password       | `secrets/db_root_password.txt`         |

These files are git-ignored and never committed. `make` creates missing
secret files with random passwords. To change a password, edit the file and
run `make re` (this resets the data, since passwords are applied at first
initialisation). Change WordPress passwords from the admin panel if you
want to keep your content.

## Check that services are running

```bash
docker compose -f srcs/docker-compose.yml ps     # all 3 should be "Up"; mariadb "healthy"
docker compose -f srcs/docker-compose.yml logs   # see service logs
curl -kI https://rapoggi.42.fr                   # expect HTTP 200 / 301
curl -kI http://rapoggi.42.fr                    # should fail: port 80 is closed
```

If the site doesn't load, check that the containers are `Up`, that
`/etc/hosts` has the domain, and look at `docker logs wordpress`.

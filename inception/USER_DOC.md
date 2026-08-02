# User Documentation

This document explains, in simple terms, how to use the Inception stack as
an end user or administrator — without needing to know how it was built.

## 1. What services does this stack provide?

The stack is made of three containers working together:

| Service    | What it does |
|------------|---------------|
| **nginx**    | The website's front door. It's the only service reachable from outside, over HTTPS on port 443. |
| **wordpress** | Runs the WordPress site itself (via php-fpm). Not reachable directly — only NGINX talks to it. |
| **mariadb**   | Stores all of WordPress's data (posts, pages, users, comments, settings). Not reachable directly either. |

In short: you visit the website through **NGINX**, which is powered by
**WordPress**, which stores everything in **MariaDB**.

## 2. Starting and stopping the project

All commands below are run from the root of the repository (where the
`Makefile` is located).

**Start the stack** (builds images if needed, then starts all containers):
```bash
make
```

**Stop the containers** (keeps all data intact, ready to restart):
```bash
make stop
```

**Restart previously stopped containers:**
```bash
make start
```

**Fully tear down** (removes containers, but keeps your data on disk):
```bash
make down
```

**Check what's currently running:**
```bash
make status
```

## 3. Accessing the website and the administration panel

### The website

Open your browser and go to:

```
https://<your-login>.42.fr
```

Replace `<your-login>` with the domain configured in `srcs/.env`
(`DOMAIN_NAME`). Since the site uses a self-signed HTTPS certificate, your
browser will show a security warning the first time — this is expected.
Click "Advanced" and choose to proceed anyway.

> Note: the site is only accessible over **HTTPS**. Trying `http://` (no
> "s") will simply fail to connect — this is intentional.

### The administration panel

Go to:

```
https://<your-login>.42.fr/wp-admin
```

Log in with the WordPress administrator account (see below for where to
find the password). From there you can write posts, edit pages, manage
comments, change the site's appearance, and manage other users.

## 4. Locating and managing credentials

All sensitive credentials are stored as plain text files inside the
`secrets/` folder at the root of the repository (this folder is excluded
from version control on purpose — never share or commit it):

| File | Contains |
|------|----------|
| `secrets/db_root_password.txt` | The MariaDB **root** password |
| `secrets/db_password.txt` | The password for the MariaDB user WordPress connects with |
| `secrets/credentials.txt` | The WordPress administrator password and the second (non-admin) user's password |

The corresponding **usernames** (not passwords) are configured in
`srcs/.env`:

- `WP_ADMIN_USER` — the WordPress administrator's username
- `WP_USER` — the second, non-administrator WordPress user
- `MYSQL_USER` — the database user WordPress connects with

To change any password, edit the relevant file in `secrets/`, then rebuild
and restart the affected service so it picks up the new value:
```bash
make down
make
```

## 5. Checking that the services are running correctly

**Quick health check** — all three containers should show as `Up`:
```bash
docker compose -f srcs/docker-compose.yml ps
```

**Watch live logs** of everything:
```bash
make logs
```

Or of a single service:
```bash
docker compose -f srcs/docker-compose.yml logs -f wordpress
docker compose -f srcs/docker-compose.yml logs -f mariadb
docker compose -f srcs/docker-compose.yml logs -f nginx
```

**Confirm the website actually responds:**
```bash
curl -vk https://<your-login>.42.fr
```
A `HTTP/1.1 200 OK` (or similar 2xx/3xx) response means the whole chain
(NGINX → WordPress → MariaDB) is working correctly.

If a container keeps restarting instead of staying `Up`, check its logs
first (see above) — that will almost always show the actual error.

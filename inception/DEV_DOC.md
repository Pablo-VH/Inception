# Developer Documentation

This document describes how to set up, build, and work on the Inception
project from a developer's point of view.

## 1. Setting up the environment from scratch

### Prerequisites

- A Linux virtual machine with Docker Engine and the Docker Compose plugin
  installed (`docker --version` and `docker compose version` should both
  work without `sudo`, which requires your user to be in the `docker`
  group).
- `git`, to clone the repository.

### Repository layout

```
.
├── Makefile
├── .gitignore
├── secrets/
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── docker-compose.yml
    ├── .env
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/          # config files copied into the image
        │   └── tools/         # entrypoint.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/
        │   └── tools/
        └── nginx/
            ├── Dockerfile
            ├── .dockerignore
            ├── conf/
            └── tools/
```

### Configuration files

- **`srcs/.env`** — non-sensitive configuration shared by all services
  (domain name, database name, usernames, WordPress title). It is read by
  `docker-compose.yml` and injected into every container's environment,
  and it is safe to commit since it holds no passwords.
- **`secrets/*.txt`** — the actual passwords, mounted into containers as
  Docker secrets (files under `/run/secrets/<name>`), never as environment
  variables. **These files are git-ignored** (see `.gitignore`) and must be
  created locally before the first run; they are not provided in the repo.

Before your first build, create the three secret files with your own
values:
```bash
echo "your_root_password"  > secrets/db_root_password.txt
echo "your_user_password"  > secrets/db_password.txt
cat > secrets/credentials.txt <<EOF
WP_ADMIN_PASSWORD=your_admin_password
WP_USER_PASSWORD=your_user_password
EOF
```

Also make sure `DOMAIN_NAME` and `DATA_PATH` in `srcs/.env` match your
actual login and `$HOME` on the VM (`DATA_PATH` must equal `$HOME/data`).

## 2. Building and launching the project

Everything is orchestrated through the root `Makefile`, which wraps
`docker compose -f srcs/docker-compose.yml`.

```bash
make            # create data dirs, build all images, start the stack
make build      # build images only, no start
make up         # start containers (detached)
make down       # stop and remove containers
make re         # fclean + all (full rebuild from scratch)
```

Under the hood, `make all` runs, in order:
1. `data` — creates `$HOME/data/mariadb` and `$HOME/data/wordpress` on the
   host, which the named volumes bind to. This step is required *before*
   `up`, or Docker Compose will fail to mount the volumes.
2. `build` — `docker compose build`, building the three custom images
   (`mariadb`, `wordpress`, `nginx`) from their respective Dockerfiles.
3. `up` — `docker compose up -d`, starting all three containers on the
   shared `inception` network.

To rebuild a single service after editing its Dockerfile or `conf/` files:
```bash
docker compose -f srcs/docker-compose.yml build <service>
docker compose -f srcs/docker-compose.yml up -d <service>
```

## 3. Managing containers and volumes

**Containers:**
```bash
docker compose -f srcs/docker-compose.yml ps          # status
docker compose -f srcs/docker-compose.yml logs -f <service>  # follow logs
docker exec -it <service> sh                            # shell into a container
```

**Volumes:**
```bash
docker volume ls                        # list volumes (db_data, wp_data)
docker volume inspect db_data            # confirm bind path under Options.device
docker volume inspect wp_data
```

**Networks:**
```bash
docker network ls                        # confirm srcs_inception exists
```

**Full reset** (equivalent to what the evaluator runs before grading):
```bash
docker stop $(docker ps -qa); docker rm $(docker ps -qa)
docker rmi -f $(docker images -qa)
docker volume rm $(docker volume ls -q)
docker network rm $(docker network ls -q) 2>/dev/null
sudo rm -rf $HOME/data
```

## 4. Where data is stored and how it persists

The two named volumes are configured in `srcs/docker-compose.yml` with the
`local` driver and `driver_opts` of `type: none, o: bind`, pointing at real
paths on the host filesystem:

- `db_data` → `${DATA_PATH}/mariadb` (MariaDB's `/var/lib/mysql` inside
  the container)
- `wp_data` → `${DATA_PATH}/wordpress` (both WordPress's and NGINX's
  `/var/www/html` inside their containers — this volume is shared between
  the two, so NGINX can serve the PHP files that WordPress writes)

This means the data physically lives under `$HOME/data/` on the host (not
in Docker's internal storage), and **survives** container removal,
image rebuilds, and full VM reboots, as long as the volumes themselves are
not explicitly deleted (`docker volume rm`) or `make fclean` is not run.

### Why entrypoint scripts check before (re)initializing

Both `srcs/requirements/mariadb/tools/entrypoint.sh` and
`srcs/requirements/wordpress/tools/entrypoint.sh` check for the presence of
existing data before running any setup:

- MariaDB checks for `/var/lib/mysql/mysql` (the system database) —
  if present, it skips `mysql_install_db` and the initial `CREATE
  USER`/`GRANT` statements, and goes straight to starting `mysqld`.
- WordPress checks for `/var/www/html/wp-config.php` — if present, it
  skips `wp core download`, `wp config create` and `wp core install`, and
  goes straight to starting `php-fpm`.

This is what makes the stack idempotent across restarts: on a fresh volume
it performs full setup once, and on every subsequent start (including
after a VM reboot) it simply reuses the existing, already-configured data.

**Important:** the two volumes are logically coupled — if you delete one of
them, delete the other too and restart both services together, otherwise
WordPress may think it's already installed while pointing at an empty (or
mismatched) database, or vice versa.

*This project has been created as part of the 42 curriculum by pavicent.*

# Inception

## Description

**Inception** is a system administration project whose goal is to learn Docker
and Docker Compose in depth by building a small, production-style web
infrastructure entirely from scratch.

The project sets up three containerized services, each running in its own
dedicated container, built from a custom-written Dockerfile:

- **NGINX** — the single entry point of the infrastructure, serving HTTPS
  traffic on port 443 only, using TLSv1.2/TLSv1.3.
- **WordPress + php-fpm** — the web application itself, without any web
  server bundled inside the container.
- **MariaDB** — the database backing WordPress, also without any web server
  inside the container.

The three services communicate over a private Docker network, and persistent
data (the database and the WordPress files) is stored on the host machine
through two named Docker volumes, so that data survives container restarts
and reboots.

The overarching goal of the project is not just to get WordPress running,
but to understand *why* each design choice (secrets over plain environment
variables, custom Dockerfiles over ready-made images, named volumes over
simple bind mounts, a dedicated bridge network over host networking) matters
in a real infrastructure.

## Instructions

### Prerequisites

- A Linux virtual machine (this project was built and tested on Lubuntu)
- Docker Engine and the Docker Compose plugin installed
- Your user added to the `docker` group (or use `sudo` for every command)

### Setup

1. Clone this repository.
2. Create the folders that will hold persistent data, matching the path
   configured in `srcs/.env` (`DATA_PATH`):
   ```bash
   mkdir -p $HOME/data/mariadb $HOME/data/wordpress
   ```
   (this is done automatically by `make`, see below)
3. Point your domain name to your local machine by adding a line to
   `/etc/hosts`:
   ```bash
   echo "127.0.0.1 login.42.fr" | sudo tee -a /etc/hosts
   ```
   Replace `login` with the value of `DOMAIN_NAME` in `srcs/.env`.
4. Fill in `secrets/db_password.txt`, `secrets/db_root_password.txt` and
   `secrets/credentials.txt` with your own passwords (these files are
   git-ignored and must never be committed).

### Build and run

From the root of the repository:

```bash
make
```

This creates the data directories, builds the three Docker images, and
starts the stack in detached mode.

Other available targets:

```bash
make down     # stop and remove the containers
make stop     # stop the containers without removing them
make start    # restart previously stopped containers
make logs     # follow logs of all services
make status   # docker compose ps
make clean    # remove containers, images and docker-managed volumes
make fclean   # clean + delete persisted data on the host
make re       # fclean + all
```

### Access

Open `https://login.42.fr` in a browser (replace `login` with your own).
A self-signed certificate warning is expected and can be safely bypassed.

See `USER_DOC.md` for detailed usage instructions and `DEV_DOC.md` for
development-oriented documentation.

## Project description

### Docker usage and repository layout

Each service lives under `srcs/requirements/<service>/`, with its own
`Dockerfile`, a `conf/` folder for configuration files copied into the
image, and a `tools/` folder holding the `entrypoint.sh` script that runs
as PID 1 inside the container. This mirrors the structure imposed by the
subject and keeps each service's build context, configuration and runtime
logic self-contained and easy to reason about independently.

`srcs/docker-compose.yml` is the single file that wires the three services
together: it declares the build context of each Dockerfile, the shared
`inception` bridge network, the two named volumes (`db_data`, `wp_data`),
the Docker secrets, and a `restart: on-failure` policy so containers recover
automatically from crashes.

The root `Makefile` is a thin wrapper around `docker compose`: it ensures
the host directories used by the named volumes exist before anything is
built, then delegates to `docker compose build`/`up`/`down`.

### Main design choices

- Every image is built from `alpine:3.23.5` (the penultimate stable Alpine
  branch at the time of writing), chosen for its small footprint and fast
  build times compared to Debian.
- No ready-made service images are pulled from Docker Hub; only the base
  Alpine image is pulled, and every Dockerfile is written from scratch.
- Each container's entrypoint script ends by `exec`-ing its main process
  in the foreground (`mysqld`, `php-fpm83 -F`, `nginx -g "daemon off;"`),
  so that process becomes PID 1 and Docker's crash-detection and
  `restart: on-failure` policy work correctly — no `tail -f` or background
  daemon hacks are used.
- WordPress is installed and configured non-interactively using `wp-cli`
  inside the entrypoint script, so the container never boots into the
  WordPress web installer.

### Virtual Machines vs Docker

A **virtual machine** virtualizes an entire computer, including its own
kernel, running on top of a hypervisor. This gives very strong isolation,
but each VM carries the overhead of a full operating system: it is slow to
boot (minutes), heavy on disk and RAM, and generally hosts a single
monolithic environment.

A **Docker container** shares the host machine's kernel and only isolates
the process, filesystem and network namespace of the application. This
makes containers extremely lightweight: they start in a fraction of a
second, use only the resources their process needs, and can be composed by
the dozen on a single VM. The trade-off is a slightly weaker isolation
boundary than a full VM, which is an acceptable trade-off for most
application-level workloads. In this project, Docker containers run
*inside* one VM, which is itself just the environment used to host the
Docker daemon.

### Secrets vs Environment Variables

**Environment variables** (as declared in `srcs/.env`) are simple, visible
in `docker inspect`, in process listings, and in `docker compose config`
output. They are convenient for non-sensitive configuration (a domain name,
a database name, a username) but are a poor fit for secrets: they can leak
through logs, crash dumps, or accidental `echo` calls, and any process or
user with access to the container can read them trivially.

**Docker secrets** are mounted as files under `/run/secrets/<name>` inside
the container, backed by tmpfs, and are not exposed through `docker
inspect` or environment listings. In this project, all three passwords
(the database root password, the WordPress database user password, and the
WordPress admin/user credentials) are stored as Docker secrets, referencing
files under `secrets/` at the repository root — a directory that is
git-ignored so no real credential is ever committed.

### Docker Network vs Host Network

With `network_mode: host` (explicitly forbidden by the subject), a
container shares the host's network namespace entirely: no isolation, and
every port the container opens is directly exposed on the host, with no
DNS-based service discovery between containers.

With a **dedicated Docker network** (the `inception` bridge network created
in `docker-compose.yml`), containers get their own private network
namespace and can reach each other by service name (e.g. `wordpress`
resolving to the WordPress container's internal IP) through Docker's
built-in DNS. Only the ports explicitly published in `docker-compose.yml`
(here, port 443 on the NGINX container) are reachable from the host, which
is essential to enforce NGINX as the *only* entry point into the stack.

### Docker Volumes vs Bind Mounts

A **bind mount** maps an arbitrary path on the host filesystem directly
into the container. It is simple and transparent, but it is tied to the
exact host path, is not managed by Docker (no `docker volume` commands
apply to it), and can behave inconsistently depending on the host's
filesystem and permissions.

A **named volume** is managed entirely by Docker (`docker volume ls`,
`docker volume inspect`, etc.) and is decoupled from any specific host
path by default. This project uses named volumes (`db_data`, `wp_data`)
configured with the `local` driver and `driver_opts` of `type: none,
o: bind`, which is a hybrid: Docker still manages and names the volume, but
the underlying data physically lives at a specific, known path on the host
(`/home/login/data/mariadb` and `/home/login/data/wordpress`), which is
required by the subject so the evaluator can inspect the raw data on disk.

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [Alpine Linux packages](https://pkgs.alpinelinux.org/packages)
- [WordPress WP-CLI documentation](https://wp-cli.org/)
- [MariaDB Knowledge Base](https://mariadb.com/kb/en/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [Docker secrets documentation](https://docs.docker.com/engine/swarm/secrets/)

### AI usage

Claude (Anthropic) was used throughout this project as a step-by-step guide
and pair-debugging assistant, rather than to generate a finished solution
blindly. Concretely, it was used to:

- Explain the project's requirements and directory structure, and help plan
  the order in which to tackle each service (MariaDB → WordPress → NGINX →
  docker-compose → Makefile → documentation).
- Draft the initial Dockerfiles, configuration files, and entrypoint
  scripts for each service, which were then built, run and iterated on in
  the actual virtual machine.
- Diagnose and fix real runtime bugs found while testing on the VM,
  including: MariaDB not listening on the network because Alpine's default
  `mariadb-server.cnf` file was overriding a custom `skip-networking`
  setting; PHP's default `memory_limit` being too low for `wp-cli` to
  extract the WordPress package; and anonymous MariaDB accounts
  (`''@'localhost'`) shadowing the dedicated `wp_user` grant when
  connecting locally.
- Explain Docker/Compose concepts (networks, named volumes vs bind mounts,
  secrets vs environment variables, PID 1 and entrypoint best practices) in
  order to write the comparison sections of this README and prepare for the
  oral defense.
- Build a checklist mapped directly to the evaluation sheet, and interpret
  the output of diagnostic commands run on the VM (`docker compose config`,
  `docker volume inspect`, `curl -v`, MariaDB log output) to confirm the
  project satisfies each evaluation point.

All commands were executed by the student on their own virtual machine;
Claude did not have direct access to the VM at any point.

# php-fpm-nginx-wordpress

WordPress on [marcortola/php-fpm-nginx](https://github.com/marcortola/docker-php-fpm-nginx),
published as `marcortola/php-fpm-nginx-wordpress:8.5` and `:8.5-debug`. On its first start the
container renders `wp-config.php` from the `WP_DB_HOST`, `WP_DB_NAME`, `WP_DB_USER` and
`WP_DB_PASSWORD` variables and installs WordPress into its working directory, `/var/www` by
default. A working directory one level below, such as `/var/www/subdir`, serves WordPress at
`/subdir` with the multisite-directory nginx configuration. See `docker-compose.yml` for
examples.

## Non-root mode

By default the container starts as root and installs WordPress owned by `www-data` (uid 82).
That suits a production image. In development, with the project bind-mounted at `/var/www`, it
leaves root- and uid-82-owned files in the checkout. The base image's
[non-root mode](https://github.com/marcortola/docker-php-fpm-nginx#non-root-mode) avoids that,
and this image supports it: start the container as your own uid, with group 0 added:

```yaml
services:
  app:
    image: marcortola/php-fpm-nginx-wordpress:8.5-debug
    user: "${HOST_UID:-1000}:${HOST_GID:-1000}"
    group_add: ["0"]
    environment:
      HOME: /tmp
    volumes:
      - ./:/var/www
```

or `docker run --user "$(id -u):$(id -g)" --group-add 0 -e HOME=/tmp ...`. The base image's
README explains `HOST_UID`, `HOME` and where the mode works.

### What changes

Everything the base image changes applies. On top of that, when the uid is not 0,
`docker-entrypoint.d/60-install-wordpress.sh` installs WordPress owned by your uid: it does not
set the archive owner to `www-data`, does not chown `wp-content`, and keeps files and directories
that already exist in the working directory instead of overwriting them, since it cannot change
the mode of directories it does not own.

In both modes `docker-entrypoint.d/50-auto-envsubst.sh` renders in place: it overwrites the nginx
site configuration files the image prepares and writes `wp-config.php` into `/usr/src/wordpress`,
a directory group 0 can write, rather than deleting and recreating files. Root mode installs and
renders as before.

These paths have group 0 with group permissions equal to the owner's, so group 0 can write them.
This image makes nothing world-writable beyond what it did before (`/var/www/wp-content` and
`/tmp`, in both modes):

- the `.auto-tpl` render targets `/etc/nginx/wordpress/single-site.conf` and
  `/etc/nginx/wordpress/multisite-directory.conf`;
- `/etc/nginx/server-default`, which receives one of them;
- `/usr/src/wordpress`, where `wp-config.php` is rendered before the install copies it;
- `/var/www`, where WordPress is installed.

A derived image must keep them so. Its `COPY ./rootfs /` whose tree contains
`etc/nginx/server-default/`, `usr/src/wordpress/` or `var/www/` resets those directories to
`root:root` with the mode from your checkout, which your uid cannot write. Re-apply the group
after the copy, for example
`RUN chgrp 0 /etc/nginx/server-default /var/www && chmod g=u /etc/nginx/server-default /var/www`.
The [base image's README](https://github.com/marcortola/docker-php-fpm-nginx#derived-images) covers
copying a file onto a render target.

### Working directory and volumes

Docker creates a working directory or mount point that does not exist as `root:root` with mode
0755, which your uid cannot write. For WordPress in a subdirectory, create the subdirectory in
the bind mount yourself, owned by your uid, before you set `working_dir: /var/www/subdir`. A
named volume mounted below it, such as `/var/www/subdir/wp-content` in `docker-compose.yml`,
starts root-owned for the same reason; keep `wp-content` in the bind mount instead.

A new named volume at `/var/www` or `/var/www/wp-content` copies the image's directory, which
your uid can write. One created in root mode keeps its `www-data` files; hand them over once as
the base image's README describes, or remove the volume so Docker recreates it.

## Example stack

`docker-compose.yml` runs the three variants: `app` (port 10000), `app_subdir` (10001, served at
`/subdir/`) and `app_dev` (10002). With no database they answer with WordPress's "Error
establishing a database connection" page. The host ports are generic knobs, so several copies of
the stack can run side by side, one per git worktree for example: `HOST_PORT_APP_80`,
`HOST_PORT_APP_SUBDIR_80` and `HOST_PORT_APP_DEV_80`. Unset or empty, each keeps its default. The
project is named after the checkout's directory; for another stack beside one of the same name,
pass `-p <name>` or export `COMPOSE_PROJECT_NAME`.

```sh
HOST_PORT_APP_80=31201 HOST_PORT_APP_SUBDIR_80=31202 HOST_PORT_APP_DEV_80=31203 \
  docker compose -p wp-second up -d
docker compose -p wp-second down -v
```

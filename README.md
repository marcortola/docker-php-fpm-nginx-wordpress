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

Everything the base image changes applies. On top of that, when the uid is not 0:

- `docker-entrypoint.d/50-auto-envsubst.sh` renders `wp-config.php` and the nginx site
  configuration in place, into files and directories the image prepares for group 0;
- `docker-entrypoint.d/60-install-wordpress.sh` installs WordPress owned by your uid: it does not
  set the archive owner to `www-data`, does not chown `wp-content`, and keeps files and
  directories that already exist in the working directory instead of overwriting them, since it
  cannot change the mode of directories it does not own.

Root mode installs and renders as before.

These paths have group 0 with group permissions equal to the owner's, so group 0 can write them.
This image makes nothing world-writable beyond what it did before (`/var/www/wp-content` and
`/tmp`, in both modes):

- the `.auto-tpl` render targets `/etc/nginx/wordpress/single-site.conf` and
  `/etc/nginx/wordpress/multisite-directory.conf`;
- `/etc/nginx/server-default`, which receives one of them;
- `/usr/src/wordpress`, where `wp-config.php` is rendered before the install copies it;
- `/var/www`, where WordPress is installed.

### Working directory and volumes

Docker creates a working directory or mount point that does not exist as `root:root` with mode
0755, which your uid cannot write. For WordPress in a subdirectory, create the subdirectory in
the bind mount yourself, owned by your uid, before you set `working_dir: /var/www/subdir`. A
named volume mounted below it, such as `/var/www/subdir/wp-content` in `docker-compose.yml`,
starts root-owned for the same reason; keep `wp-content` in the bind mount instead.

A new named volume at `/var/www` or `/var/www/wp-content` copies the image's directory, which
your uid can write. One created in root mode keeps its `www-data` files; hand them over once as
the base image's README describes, or remove the volume so Docker recreates it.

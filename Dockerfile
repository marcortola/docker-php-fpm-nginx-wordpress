ARG PHP_VERSION=8.5
ARG WP_VERSION=7

### BASE ###
FROM wordpress:${WP_VERSION}-fpm-alpine as wordpress

FROM marcortola/php-fpm-nginx:${PHP_VERSION} as base
ARG USER=www-data
ENV USER=${USER} \
	WP_DB_HOST=localhost \
	WP_DB_NAME=secret \
	WP_DB_USER=secret \
	WP_DB_PASSWORD=secret

## Install deps
RUN apk add --update --no-cache \
        imagemagick

# Setup PHP
RUN install-php-extensions \
	bcmath \
	exif \
	zip \
	gd \
	mysqli \
	imagick \
	redis \
    && mkdir -p /var/run/php/

# Setup files
COPY --chown=${USER}:${USER} --from=wordpress /usr/src/wordpress /usr/src/wordpress
COPY --chown=${USER}:${USER} ./rootfs /
RUN mkdir wp-content wp-content/plugins wp-content/themes \
    && chown -R ${USER}:${USER} wp-content \
    && chmod -R 777 wp-content /tmp \
    && find /usr/local/bin/ -type f -name "*.sh" -exec chmod +x {} \;

# Non-root mode (see README.md): on top of the base image's paths, a container started as an
# arbitrary uid with group 0 added can write exactly these, and nothing new is world-writable.
# They are the nginx .auto-tpl render targets, the directory 50-auto-envsubst.sh copies the site
# configuration into, /usr/src/wordpress for wp-config.php, and /var/www, where
# 60-install-wordpress.sh installs WordPress. wp-config.php itself is not pre-created: when the
# working directory has one but no WordPress yet, 50-auto-envsubst.sh skips the render and
# 60-install-wordpress.sh would install the empty file over it.
RUN set -eu; \
	for file in /etc/nginx/wordpress/single-site.conf \
		/etc/nginx/wordpress/multisite-directory.conf; do \
		touch "$file"; \
		chgrp 0 "$file"; \
		chmod g=u "$file"; \
	done; \
	mkdir -p /etc/nginx/server-default; \
	for dir in /etc/nginx/server-default /usr/src/wordpress /var/www; do \
		chgrp 0 "$dir"; \
		chmod g=u "$dir"; \
	done

### DEBUG ###
FROM marcortola/php-fpm-nginx:${PHP_VERSION}-debug AS base_debug
FROM base as debug
COPY --from=base_debug / /
# The copy resets the metadata of the directories base_debug has too, /var/www among them.
RUN chgrp 0 /var/www \
	&& chmod g=u /var/www

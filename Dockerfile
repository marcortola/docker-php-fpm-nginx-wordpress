ARG PHP_VERSION=7.4
ARG WP_VERSION=6.1

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

### DEBUG ###
FROM marcortola/php-fpm-nginx:${PHP_VERSION}-debug AS base_debug
FROM base as debug
COPY --from=base_debug / /

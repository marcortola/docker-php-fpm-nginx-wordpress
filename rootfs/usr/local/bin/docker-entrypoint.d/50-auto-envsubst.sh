#!/bin/sh

set -e

export WP_RAND="${WP_RAND:-$(openssl rand -hex 16)}"
export WP_NGINX_CACHE="${NGINX_CACHE_DIR%/}/php"

if [[ $APP_DEBUG -eq 1 ]]; then
	export WP_DEBUG=true
else
	export WP_DEBUG=false
fi

if echo "$PWD" | grep -q "^/var/www/[^/]\+/\?$"; then
	PWD="${PWD%/}"
    export WP_SUBDIR="${PWD##*/}"
fi

# The nginx configuration is rendered on every start: the base image's 20-auto-envsubst.sh renders
# it first without the WP_ variables, which leaves $WP_SUBDIR in it. wp-config.php is rendered
# only for a working directory that has none yet.
template_dirs="/etc/nginx/wordpress"
[ -e wp-config.php ] || template_dirs="/usr/src/wordpress $template_dirs"
suffix=".auto-tpl"
filter="(WP_)"

defined_envs=$(printf '${%s} ' $(awk "END { for (name in ENVIRON) { print ( name ~ /${filter}/ ) ? name : \"\" } }" </dev/null))

echo "$template_dirs" | tr ' ' '\n' | while read -r path; do
	find "$path" -type f -name "*$suffix" -print | while read -r template; do
		file="${template%$suffix}"
		# Render in place, in both modes: in non-root mode (see README.md) the uid can write the
		# nginx render targets the Dockerfile prepares but not delete them, and it creates
		# wp-config.php in /usr/src/wordpress, a directory the Dockerfile makes writable.
		envsubst "$defined_envs" <"$template" >"$file"
	done
done

mkdir -p /etc/nginx/server-default

if [ -z "$WP_SUBDIR" ]; then
	cp /etc/nginx/wordpress/single-site.conf /etc/nginx/server-default
else
	cp /etc/nginx/wordpress/multisite-directory.conf /etc/nginx/server-default
fi

exit 0

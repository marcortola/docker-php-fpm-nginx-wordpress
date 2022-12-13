#!/bin/sh

set -e

export WP_RAND="${WP_RAND:-$(openssl rand -hex 16)}"
export WP_NGINX_CACHE="${NGINX_CACHE_DIR%/}/php"

if [ $APP_DEBUG -eq 1 ]; then
	export WP_DEBUG=true
else
	export WP_DEBUG=false
fi

template_dirs="/usr/src/wordpress"
suffix=".auto-tpl"
filter="(WP_)"

if [ ! -e wp-config.php ]; then
	defined_envs=$(printf '${%s} ' $(awk "END { for (name in ENVIRON) { print ( name ~ /${filter}/ ) ? name : \"\" } }" </dev/null))

	echo "$template_dirs" | tr ' ' '\n' | while read -r path; do
		find "$path" -type f -name "*$suffix" -print | while read -r template; do
			file="${template%$suffix}"
			rm -f "$file"
			envsubst "$defined_envs" <"$template" >"$file"
		done
	done

	exit 0
fi

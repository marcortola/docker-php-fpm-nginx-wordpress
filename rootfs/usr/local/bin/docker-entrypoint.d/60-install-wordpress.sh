#!/bin/sh

set -eu

set -- --create --file - --directory /usr/src/wordpress --owner "$USER" --group "$USER"

if [ ! -e index.php ] && [ ! -e wp-includes/version.php ]; then

	for contentPath in /usr/src/wordpress/.htaccess /usr/src/wordpress/wp-content/*/*/; do
		contentPath="${contentPath%/}"
		[ -e "$contentPath" ] || continue
		contentPath="${contentPath#/usr/src/wordpress/}"
		if [ -e "$PWD/$contentPath" ]; then
			set -- "$@" --exclude "./$contentPath"
		fi
	done

	tar "$@" . | tar --extract --file - --no-overwrite-dir

	chown -R $USER:$USER wp-content
fi

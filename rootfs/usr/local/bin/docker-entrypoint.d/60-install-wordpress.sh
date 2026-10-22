#!/bin/sh

set -eu

set -- --create --file - --directory /usr/src/wordpress

# Non-root mode (see README.md): the container runs as an arbitrary uid with group 0 added, so
# nothing can be chowned and the files land owned by that uid. tar cannot change the mode of a
# directory it does not own, which --no-overwrite-dir does to each one that already exists, such
# as the image's wp-content in a new named volume; --skip-old-files leaves existing entries as
# they are instead.
if [ "$(id -u)" = "0" ]; then
	nonroot=false
	set -- "$@" --owner "$USER" --group "$USER"
	extract_option=--no-overwrite-dir
else
	nonroot=true
	extract_option=--skip-old-files
fi

if [ ! -e index.php ] && [ ! -e wp-includes/version.php ]; then

	for contentPath in /usr/src/wordpress/.htaccess /usr/src/wordpress/wp-content/*/*/; do
		contentPath="${contentPath%/}"
		[ -e "$contentPath" ] || continue
		contentPath="${contentPath#/usr/src/wordpress/}"
		if [ -e "$PWD/$contentPath" ]; then
			set -- "$@" --exclude "./$contentPath"
		fi
	done

	tar "$@" . | tar --extract --file - "$extract_option"

	if [ "$nonroot" = false ]; then
		chown -R $USER:$USER wp-content
	fi
fi

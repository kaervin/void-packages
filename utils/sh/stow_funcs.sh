#-
# Copyright (c) 2008 Juan Romero Pardines.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#-

#
# Stow a package, i.e copy files from destdir into masterdir
# and register pkg into the package database.
#
stow_pkg()
{
	local pkg="$1"
	local i=

	[ -z "$pkg" ] && return 2

	if [ "$build_style" = "meta-template" ]; then
		[ ! -d $XBPS_DESTDIR/$pkgname-$version ] && \
			mkdir -p $XBPS_DESTDIR/$pkgname-$version
	fi

	if [ -n "$stow_flag" ]; then
		pkg=$XBPS_TEMPLATESDIR/$pkg.tmpl
		if [ "$pkgname" != "$pkg" ]; then
			. $pkg
		fi
		pkg=$pkgname-$version
	fi

	cd $XBPS_DESTDIR/$pkgname-$version || exit 1

	# Write pkg metadata.
	. $XBPS_SHUTILSDIR/binpkg.sh
	xbps_write_metadata_pkg

	# Copy metadata files into masterdir.
	if [ -f xbps-metadata/flist -a -f xbps-metadata/props.plist ]; then
		local metadir=$XBPS_PKGMETADIR/$pkgname
		mkdir -p $metadir
		cp -f xbps-metadata/flist $metadir
		cp -f xbps-metadata/props.plist $metadir
	fi

	# Copy files into masterdir.
	for i in $(echo *); do
		[ "$i" = "xbps-metadata" ] && continue
		cp -ar ${i} $XBPS_MASTERDIR
	done

	$XBPS_PKGDB_CMD register $pkgname $version "$short_desc"
	[ $? -ne 0 ] && exit 1

	#
	# Run template postinstall helpers if requested.
	#
	if [ "$pkgname" != "${pkg%%-$version}" ]; then
		. $XBPS_TEMPLATESDIR/${pkg%%-$version}.tmpl
	fi

	for i in ${postinstall_helpers}; do
		local pihf="$XBPS_HELPERSDIR/$i"
		[ -f "$pihf" ] && . $pihf
	done
}

#
# Unstow a package, i.e remove its files from masterdir and
# unregister pkg from package database.
#
unstow_pkg()
{
	local pkg="$1"
	local f=
	local ver=

	[ -z $pkg ] && msg_error "template wasn't specified?"

	if [ "$pkgname" != "$pkg" ]; then
		. $XBPS_TEMPLATESDIR/$pkg.tmpl
	fi

	ver=$($XBPS_PKGDB_CMD version $pkg)
	if [ -z "$ver" ]; then
		msg_error "$pkg is not installed."
	fi

	cd $XBPS_PKGMETADIR/$pkgname || exit 1
	if [ ! -f flist ]; then
		msg_error "$pkg is incomplete, missing flist."
	elif [ ! -O flist ]; then
		msg_error "$pkg cannot be removed (permission denied)."
	fi

	# Remove installed files.
	for f in $(cat flist); do
		if [ -f $XBPS_MASTERDIR/$f -o -h $XBPS_MASTERDIR/$f ]; then
			rm $XBPS_MASTERDIR/$f  >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "Removing file: $f"
			fi
		fi
	done

	for f in $(cat flist); do
		if [ -d $XBPS_MASTERDIR/$f ]; then
			rmdir $XBPS_MASTERDIR/$f >/dev/null 2>&1
			if [ $? -eq 0 ]; then
				echo "Removing directory: $f"
			fi
		fi
	done

	# Remove metadata dir.
	rm -rf $XBPS_PKGMETADIR/$pkgname

	$XBPS_PKGDB_CMD unregister $pkgname $ver
	return $?
}
